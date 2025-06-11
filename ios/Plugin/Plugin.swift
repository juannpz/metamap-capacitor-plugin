import Foundation
import Capacitor
import MetaMapSDK
import UIKit

extension UIColor {
    convenience init?(hexString: String) {
        var cString: String = hexString.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if cString.hasPrefix("#") {
            cString.remove(at: cString.startIndex)
        }
        if (cString.count) != 6 {
            return nil
        }
        var rgbValue: UInt64 = 0
        Scanner(string: cString).scanHexInt64(&rgbValue)
        self.init(
            red: CGFloat((rgbValue & 0xFF0000) >> 16) / 255.0,
            green: CGFloat((rgbValue & 0x00FF00) >> 8) / 255.0,
            blue: CGFloat(rgbValue & 0x0000FF) / 255.0,
            alpha: CGFloat(1.0)
        )
    }
}

@objc(MetaMapCapacitorPlugin)
public class MetaMapCapacitorPlugin: CAPPlugin {

    private var pluginCall: CAPPluginCall?

    static let EVENT_SDK_STARTED = "metamapSdkStarted"
    static let EVENT_FLOW_COMPLETED = "metamapFlowCompleted"
    static let EVENT_FLOW_ABANDONED = "metamapFlowAbandoned"
    static let TAG = "📲 MetaMapCapacitorPlugin"

    @objc func showMetaMapFlow(_ call: CAPPluginCall) {
        self.pluginCall = call

        guard let clientId = call.getString("clientId"), !clientId.isEmpty else {
            CAPLog.print("❌ [\(MetaMapCapacitorPlugin.TAG)] Missing clientId")
            call.reject("Client Id should not be null or empty")
            return
        }

        let flowId = call.getString("flowId")
        let metadataFromCall = call.getObject("metadata") ?? [:]
        var processedMetadata: [String: Any] = [:]
        for (key, value) in metadataFromCall {
            if key.lowercased().contains("color"), let colorString = value as? String {
                if UIColor(hexString: colorString) == nil {
                     CAPLog.print("🎨⚠️ [\(MetaMapCapacitorPlugin.TAG)] Invalid hex color string for key '\(key)': \(colorString). Passing original string value.")
                } else {
                    CAPLog.print("🎨 [\(MetaMapCapacitorPlugin.TAG)] Parsed color string for key '\(key)': \(colorString)")
                }
                processedMetadata[key] = colorString
            } else {
                processedMetadata[key] = value
            }
        }
        processedMetadata["sdkType"] = "capacitor"

        CAPLog.print("🚀 [\(MetaMapCapacitorPlugin.TAG)] Starting flow with:")
        CAPLog.print("   • clientId: \(clientId)")
        if let fId = flowId { CAPLog.print("   • flowId: \(fId)") } else { CAPLog.print("   • flowId: nil") }
        CAPLog.print("   • metadata: \(processedMetadata)")

        DispatchQueue.main.async { [weak self] in
            guard let self = self else {
                CAPLog.print("❌ [\(MetaMapCapacitorPlugin.TAG)] Plugin instance (self) was nil before showing MetaMap flow.")
                call.reject("Failed to show MetaMap flow: Plugin instance is not available.")
                return
            }
            
            if UIApplication.shared.windows.filter({$0.isKeyWindow}).first?.rootViewController == nil {
                CAPLog.print("☢️ [\(MetaMapCapacitorPlugin.TAG)] Warning: No root view controller found on the key window. MetaMap SDK might fail to present UI.")
            }

            MetaMapButtonResult.shared.delegate = self
            
            CAPLog.print("✅ [\(MetaMapCapacitorPlugin.TAG)] Calling MetaMap.shared.showMetaMapFlow (without explicit presentingViewController parameter)")
            // Llamada al SDK que compila para ti (sin 'presentingViewController' como parámetro explícito)
            MetaMap.shared.showMetaMapFlow(
                clientId: clientId,
                flowId: flowId,
                metadata: processedMetadata
            )
        }
    }

    private func buildResultPayload(identityId: String?, verificationID: String?) -> [String: Any] {
        var result: [String: Any] = [:]
        result["identityId"] = identityId ?? NSNull()
        result["verificationId"] = verificationID ?? NSNull()
        return result
    }
    
    private func finalizeCall() {
        self.pluginCall = nil
        MetaMapButtonResult.shared.delegate = nil
        CAPLog.print("🔵 [\(MetaMapCapacitorPlugin.TAG)] Plugin call finalized and MetaMapButtonResult delegate cleared.")
    }
}

extension MetaMapCapacitorPlugin: MetaMapButtonResultDelegate {

    public func verificationCreated(identityId: String?, verificationID: String?) {
        let identityLog = identityId ?? "nil (string)"
        let verificationLog = verificationID ?? "nil (string)"
        CAPLog.print("🟡 [\(MetaMapCapacitorPlugin.TAG)] \(MetaMapCapacitorPlugin.EVENT_SDK_STARTED): identityId=\(identityLog), verificationId=\(verificationLog)")
        let payload = buildResultPayload(identityId: identityId, verificationID: verificationID)
        self.notifyListeners(MetaMapCapacitorPlugin.EVENT_SDK_STARTED, data: payload)
    }

    public func verificationSuccess(identityId: String?, verificationID: String?) {
        let identityLog = identityId ?? "nil (string)"
        let verificationLog = verificationID ?? "nil (string)"
        CAPLog.print("✅ [\(MetaMapCapacitorPlugin.TAG)] Flow completed (verificationSuccess): identityId=\(identityLog), verificationId=\(verificationLog)")
        
        guard let call = self.pluginCall else {
            CAPLog.print("❌ [\(MetaMapCapacitorPlugin.TAG)] PluginCall object was null in verificationSuccess.")
            let payloadNoCall = buildResultPayload(identityId: identityId, verificationID: verificationID)
            self.notifyListeners(MetaMapCapacitorPlugin.EVENT_FLOW_COMPLETED, data: payloadNoCall)
            MetaMapButtonResult.shared.delegate = nil 
            return
        }
        
        let payload = buildResultPayload(identityId: identityId, verificationID: verificationID)
        self.notifyListeners(MetaMapCapacitorPlugin.EVENT_FLOW_COMPLETED, data: payload)
        call.resolve(payload)
        self.finalizeCall()
    }

    public func verificationCancelled(identityId: String?, verificationID: String?) {
        let identityLog = identityId ?? "nil (string)"
        let verificationLog = verificationID ?? "nil (string)"
        CAPLog.print("❌ [\(MetaMapCapacitorPlugin.TAG)] Flow abandoned or cancelled (verificationCancelled): identityId=\(identityLog), verificationId=\(verificationLog)")
        
        guard let call = self.pluginCall else {
            CAPLog.print("❌ [\(MetaMapCapacitorPlugin.TAG)] PluginCall object was null in verificationCancelled.")
            let payloadNoCall = buildResultPayload(identityId: identityId, verificationID: verificationID)
            self.notifyListeners(MetaMapCapacitorPlugin.EVENT_FLOW_ABANDONED, data: payloadNoCall)
            MetaMapButtonResult.shared.delegate = nil
            return
        }
        
        let payload = buildResultPayload(identityId: identityId, verificationID: verificationID)
        self.notifyListeners(MetaMapCapacitorPlugin.EVENT_FLOW_ABANDONED, data: payload)
        call.reject(
            "Verification flow was abandoned or cancelled by the user.",
            "FLOW_ABANDONED_OR_CANCELLED",
            nil,
            payload
        )
        self.finalizeCall()
    }
}