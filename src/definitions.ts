import type { PluginListenerHandle } from '@capacitor/core';

export interface MetaMapParams {
    clientId: string;
    flowId: string;
    metadata?: object;
}

export interface MetamapEventData {
    identityId: string | null;
    verificationId: string | null;
}

export const METAMAP_SDK_STARTED_EVENT = 'metamapSdkStarted' as const;
export const METAMAP_FLOW_COMPLETED_EVENT = 'metamapFlowCompleted' as const;
export const METAMAP_FLOW_ABANDONED_EVENT = 'metamapFlowAbandoned' as const;

export type MetamapPluginEvents =
    | typeof METAMAP_SDK_STARTED_EVENT
    | typeof METAMAP_FLOW_COMPLETED_EVENT
    | typeof METAMAP_FLOW_ABANDONED_EVENT;

export interface MetaMapCapacitorPlugin {
    showMetaMapFlow(options: MetaMapParams): Promise<{ identityId: string | null, verificationId: string | null }>;

    addListener(
        eventName: typeof METAMAP_SDK_STARTED_EVENT,
        listenerFunc: (data: MetamapEventData) => void
    ): Promise<PluginListenerHandle> & PluginListenerHandle;

    addListener(
        eventName: typeof METAMAP_FLOW_COMPLETED_EVENT,
        listenerFunc: (data: MetamapEventData) => void
    ): Promise<PluginListenerHandle> & PluginListenerHandle;

    addListener(
        eventName: typeof METAMAP_FLOW_ABANDONED_EVENT,
        listenerFunc: (data: MetamapEventData) => void
    ): Promise<PluginListenerHandle> & PluginListenerHandle;

    removeAllListeners(): Promise<void>;
}