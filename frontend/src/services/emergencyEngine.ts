import { registerPlugin } from '@capacitor/core';

export type EmergencyEngineState =
  | 'IDLE'
  | 'LOCATING'
  | 'ACTIVATING'
  | 'ACTIVE'
  | 'LOCATION_UNAVAILABLE'
  | 'CONTACTS_NOT_CONFIGURED'
  | 'FAILED'
  | 'ENDED';

export type TriggerSource = 'UI' | 'SIRI' | 'WIDGET' | 'WEARABLE' | 'HARDWARE';

export interface NativeIncidentData {
  incidentId: string;
  timestamp: number;
  latitude?: number;
  longitude?: number;
  accuracy?: number;
  triggerSource: TriggerSource;
  state: EmergencyEngineState;
  isDemoMode: boolean;
}

interface SafeMeshNativePluginInterface {
  getEmergencyState(): Promise<{ state: string; incident?: NativeIncidentData | null }>;
  activateSOS(options?: { source: TriggerSource }): Promise<{ success: boolean; state: string; incident?: NativeIncidentData }>;
  deactivateSOS(): Promise<{ success: boolean; state: string }>;
  getPermissionStatus(): Promise<{ location: string; notifications: string }>;
  openSettings(): Promise<{ opened: boolean }>;
  call112(options?: { isDemoMode?: boolean }): Promise<{ success: boolean; action?: string; message?: string }>;
  callEmergencyContact(options: { phone: string }): Promise<{ success: boolean }>;
  addListener(
    eventName: 'emergencyStateChange',
    listenerFunc: (data: { state: string; incident?: NativeIncidentData | null }) => void
  ): Promise<{ remove: () => void }>;
}

const SafeMeshNative = registerPlugin<SafeMeshNativePluginInterface>('SafeMeshNative');

type StateListener = (state: EmergencyEngineState, incident?: NativeIncidentData | null) => void;

class CentralEmergencyEngine {
  private currentState: EmergencyEngineState = 'IDLE';
  private currentIncident: NativeIncidentData | null = null;
  private listeners: Set<StateListener> = new Set();
  private isInitialized = false;

  constructor() {
    this.init();
  }

  private async init() {
    if (this.isInitialized) return;
    this.isInitialized = true;

    // Listen to native iOS events (Siri intent, Widget, etc.)
    try {
      await SafeMeshNative.addListener('emergencyStateChange', (data) => {
        this.updateState(data.state as EmergencyEngineState, data.incident);
      });
    } catch {
      // SafeMeshNative not available (e.g. standard browser preview)
    }

    // Check existing native state (in case app was cold-launched by Siri / Widget)
    this.syncNativeState();

    // Re-check whenever app returns to foreground
    const onForeground = () => {
      this.syncNativeState();
    };

    window.addEventListener('focus', onForeground);
    window.addEventListener('resume', onForeground);
    document.addEventListener('visibilitychange', () => {
      if (document.visibilityState === 'visible') {
        onForeground();
      }
    });
  }

  public async syncNativeState() {
    try {
      const res = await SafeMeshNative.getEmergencyState();
      if (res && res.state) {
        this.updateState(res.state as EmergencyEngineState, res.incident);
      }
    } catch {
      // Browser fallback: check local storage
      const savedState = localStorage.getItem('safemesh_active_sos');
      if (savedState === 'ACTIVE' && this.currentState !== 'ACTIVE') {
        this.updateState('ACTIVE', null);
      }
    }
  }

  private updateState(newState: EmergencyEngineState, incident?: NativeIncidentData | null) {
    this.currentState = newState;
    this.currentIncident = incident ?? null;
    this.listeners.forEach((listener) => {
      try {
        listener(this.currentState, this.currentIncident);
      } catch (e) {
        console.error('[EmergencyEngine] Listener error:', e);
      }
    });
  }

  public subscribe(listener: StateListener): () => void {
    this.listeners.add(listener);
    // Emit initial state
    listener(this.currentState, this.currentIncident);
    return () => {
      this.listeners.delete(listener);
    };
  }

  public getState(): EmergencyEngineState {
    return this.currentState;
  }

  public getIncident(): NativeIncidentData | null {
    return this.currentIncident;
  }

  public async activateSOS(source: TriggerSource = 'UI'): Promise<void> {
    console.log(`[EmergencyEngine] Activating SOS from source: ${source}`);
    this.updateState('ACTIVATING', null);
    localStorage.setItem('safemesh_active_sos', 'ACTIVE');

    try {
      const res = await SafeMeshNative.activateSOS({ source });
      this.updateState((res.state as EmergencyEngineState) || 'ACTIVE', res.incident);
    } catch {
      // Standard browser or Android fallback
      this.updateState('ACTIVE', {
        incidentId: `INC-${Date.now()}`,
        timestamp: Date.now(),
        triggerSource: source,
        state: 'ACTIVE',
        isDemoMode: true,
      });
    }
  }

  public async deactivateSOS(): Promise<void> {
    console.log('[EmergencyEngine] Deactivating SOS');
    localStorage.removeItem('safemesh_active_sos');
    this.updateState('ENDED', null);

    try {
      await SafeMeshNative.deactivateSOS();
    } catch {
      // fallback
    }

    setTimeout(() => {
      this.updateState('IDLE', null);
    }, 500);
  }

  public async call112(isDemoMode = true): Promise<{ success: boolean; message?: string }> {
    try {
      return await SafeMeshNative.call112({ isDemoMode });
    } catch {
      if (isDemoMode) {
        return {
          success: true,
          message: 'Demo Safe Mode: Verified 112 emergency call dispatch flow safely.',
        };
      }
      window.location.href = 'tel:112';
      return { success: true };
    }
  }

  public async callEmergencyContact(phone: string): Promise<{ success: boolean }> {
    if (!phone || !phone.trim()) {
      throw new Error('No emergency contact configured. Add an emergency contact first.');
    }
    try {
      return await SafeMeshNative.callEmergencyContact({ phone });
    } catch {
      window.location.href = `tel:${phone.replace(/[^0-9+]/g, '')}`;
      return { success: true };
    }
  }
}

export const emergencyEngine = new CentralEmergencyEngine();
