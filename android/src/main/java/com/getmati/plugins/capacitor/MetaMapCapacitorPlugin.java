package com.getmati.plugins.capacitor;

import android.app.Activity;
import android.content.Intent;
import android.graphics.Color;
import android.util.Log;
import androidx.activity.result.ActivityResult;

import com.getcapacitor.JSObject;
import com.getcapacitor.Plugin;
import com.getcapacitor.PluginCall;
import com.getcapacitor.PluginMethod;
import com.getcapacitor.annotation.ActivityCallback;
import com.getcapacitor.annotation.CapacitorPlugin;
import com.metamap.metamap_sdk.MetamapSdk;
import com.metamap.metamap_sdk.Metadata;

import org.json.JSONException;
import org.json.JSONObject;

import java.util.Iterator;

import kotlin.Unit;

@CapacitorPlugin(name = "MetaMapCapacitor")
public class MetaMapCapacitorPlugin extends Plugin {

    private static final String TAG = "📲 MetaMapCapacitor";

    public static final String EVENT_SDK_STARTED = "metamapSdkStarted";
    public static final String EVENT_FLOW_COMPLETED = "metamapFlowCompleted";
    public static final String EVENT_FLOW_ABANDONED = "metamapFlowAbandoned";

    @PluginMethod
    public void showMetaMapFlow(PluginCall call) {
        Log.d(TAG, "🔔 showMetaMapFlow invoked");

        bridge.getActivity().runOnUiThread(() -> {
            String clientId = call.getString("clientId");
            String flowId = call.getString("flowId");
            JSONObject metadataFromCall = call.getObject("metadata", new JSObject());

            if (clientId == null || clientId.isEmpty()) {
                Log.e(TAG, "❌ Missing clientId");
                call.reject("Client Id should not be null or empty");
                return;
            }

            try {
                Metadata.Builder metadataBuilder = new Metadata.Builder();

                if (metadataFromCall != null) {
                    Iterator<String> keys = metadataFromCall.keys();
                    while (keys.hasNext()) {
                        String key = keys.next();
                        try {
                            Object value = metadataFromCall.get(key);

                            if (key.toLowerCase().contains("color") && value instanceof String) {
                                String hexColor = (String) value;
                                try {
                                    int parsedColor = Color.parseColor(hexColor);
                                    metadataBuilder.with(key, parsedColor);
                                    Log.d(TAG, "🎨 Parsed color for key '" + key + "': " + hexColor + " -> " + parsedColor);
                                } catch (IllegalArgumentException e) {
                                    Log.e(TAG, "⚠️ Invalid color string for key '" + key + "': " + hexColor + ". Passing original string value.", e);
                                    metadataBuilder.with(key, value);
                                }
                            } else {
                                metadataBuilder.with(key, value);
                            }
                        } catch (JSONException e) {
                            Log.e(TAG, "⚠️ Error processing metadata key: " + key, e);
                        }
                    }
                }

                metadataBuilder.with("sdkType", "capacitor");
                Metadata builtMetadata = metadataBuilder.build();

                Intent flowIntent = MetamapSdk.INSTANCE.createFlowIntent(
                        bridge.getActivity(),
                        clientId,
                        flowId,
                        builtMetadata,
                        null,
                        null,
                        (identityId, verificationId) -> {
                            Log.d(TAG, "🟡 " + EVENT_SDK_STARTED + ": identityId=" + identityId + ", verificationId=" + verificationId);
                            JSObject startedResult = new JSObject();
                            startedResult.put("identityId", identityId != null ? identityId : JSONObject.NULL);
                            startedResult.put("verificationId", verificationId != null ? verificationId : JSONObject.NULL);
                            notifyListeners(EVENT_SDK_STARTED, startedResult);
                            return Unit.INSTANCE;
                        }
                );

                Log.d(TAG, "🚀 Starting MetaMap flow...");
                startActivityForResult(call, flowIntent, "callback");

            } catch (Exception e) {
                Log.e(TAG, "🔥 Failed to start MetaMap flow", e);
                call.reject("Failed to start MetaMap flow: " + e.getMessage());
            }
        });
    }

    @ActivityCallback
    private void callback(PluginCall call, ActivityResult activityResult) {
        if (call == null) {
            Log.e(TAG, "❌ PluginCall object was null in @ActivityCallback. This should not happen.");
            return;
        }

        Intent data = activityResult.getData();
        String identityId = null;
        String verificationId = null;

        JSObject resultDataPayload = new JSObject();

        if (data != null) {
            identityId = data.getStringExtra(MetamapSdk.ARG_IDENTITY_ID);
            verificationId = data.getStringExtra(MetamapSdk.ARG_VERIFICATION_ID);

            resultDataPayload.put("identityId", identityId != null ? identityId : JSONObject.NULL);
            resultDataPayload.put("verificationId", verificationId != null ? verificationId : JSONObject.NULL);
        } else {
            resultDataPayload.put("identityId", JSONObject.NULL);
            resultDataPayload.put("verificationId", JSONObject.NULL);
            Log.w(TAG, "onActivityResult data is null. identityId and verificationId will be null.");
        }


        if (activityResult.getResultCode() == Activity.RESULT_OK) {
            Log.d(TAG, "✅ Flow completed (Activity.RESULT_OK): identityId=" + identityId + ", verificationId=" + verificationId);
            notifyListeners(EVENT_FLOW_COMPLETED, resultDataPayload);
            call.resolve(resultDataPayload);
        } else {
            Log.d(TAG, "❌ Flow abandoned or cancelled (Activity.RESULT_CODE != OK): identityId=" + identityId + ", verificationId=" + verificationId + ", resultCode=" + activityResult.getResultCode());
            notifyListeners(EVENT_FLOW_ABANDONED, resultDataPayload);
            call.reject(
                    "Verification flow was abandoned or cancelled by the user.",
                    "FLOW_ABANDONED_OR_CANCELLED",
                    null,
                    resultDataPayload
            );
        }
    }
}