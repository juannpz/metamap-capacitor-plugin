import { registerPlugin, PluginListenerHandle } from '@capacitor/core';
import type {
    MetaMapCapacitorPlugin,
    MetaMapParams,
    MetamapEventData,
    METAMAP_SDK_STARTED_EVENT,
    METAMAP_FLOW_COMPLETED_EVENT,
    METAMAP_FLOW_ABANDONED_EVENT
} from './definitions';

const capacitorPluginInstance = registerPlugin<MetaMapCapacitorPlugin>('MetaMapCapacitor', {
});

const MetaMapCapacitor: MetaMapCapacitorPlugin = {
    showMetaMapFlow: (options: MetaMapParams): Promise<{ identityId: string | null, verificationId: string | null }> => {
        const { metadata } = options;

        return capacitorPluginInstance.showMetaMapFlow({ ...options, metadata: { ...metadata, sdkType: "capacitor" } });
    },
    addListener: (
        eventName:
            | typeof METAMAP_SDK_STARTED_EVENT
            | typeof METAMAP_FLOW_COMPLETED_EVENT
            | typeof METAMAP_FLOW_ABANDONED_EVENT,
        listenerFunc: (data: MetamapEventData) => void
    ): Promise<PluginListenerHandle> & PluginListenerHandle => {
        return capacitorPluginInstance.addListener(eventName as any, listenerFunc);
    },

    removeAllListeners: (): Promise<void> => {
        return capacitorPluginInstance.removeAllListeners();
    }
};

export * from './definitions';

export { MetaMapCapacitor };
