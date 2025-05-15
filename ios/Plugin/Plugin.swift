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
            CAPLog.print("❌ Missing clientId")
            call.reject("Client Id should not be null or empty")
            return
        }

        let flowId = call.getString("flowId")
        var metadataFromCall = call.getObject("metadata") ?? [:]

        var processedMetadata: [String: Any] = [:]
        for (key, value) in metadataFromCall {
            if key.lowercased().contains("color"), let colorString = value as? String {
                if UIColor(hexString: colorString) == nil {
                     CAPLog.print("🎨⚠️ Invalid hex color string for key '\(key)': \(colorString). Passing original string value.")
                } else {
                    CAPLog.print("🎨 Parsed color string for key '\(key)': \(colorString)")
                }
                processedMetadata[key] = colorString
            } else {
                processedMetadata[key] = value
            }
        }

        processedMetadata["sdkType"] = "capacitor"

        CAPLog.print("🚀 [\(MetaMapCapacitorPlugin.TAG)] Starting flow with:")
        CAPLog.print("   • clientId: \(clientId)")
        if let fId = flowId { CAPLog.print("   • flowId: \(fId)") }
        CAPLog.print("   • metadata: \(processedMetadata)")

        DispatchQueue.main.async {
            MetaMapButtonResult.shared.delegate = self
            MetaMap.shared.showMetaMapFlow(
                presentingViewController: self.bridge?.viewController,
                clientId: clientId,
                flowId: flowId,
                metadata: processedMetadata,
                encryptionDelegate: nil
            )
        }
    }

    private func buildResultPayload(identityId: String?, verificationID: String?) -> [String: Any] {
        var result: [String: Any] = [:]
        result["identityId"] = identityId ?? NSNull()
        result["verificationId"] = verificationID ?? NSNull()
        return result
    }
}

extension MetaMapCapacitorPlugin: MetaMapButtonResultDelegate {

    public func verificationCreated(identityId: String?, verificationID: String?) {
        let identity = identityId ?? "nil (string)"
        let verification = verificationID ?? "nil (string)"
        CAPLog.print("🟡 [\(MetaMapCapacitorPlugin.TAG)] \(MetaMapCapacitorPlugin.EVENT_SDK_STARTED): identityId=\(identity), verificationId=\(verification)")

        let payload = buildResultPayload(identityId: identityId, verificationID: verificationID)
        self.notifyListeners(MetaMapCapacitorPlugin.EVENT_SDK_STARTED, data: payload)
    }

    public func verificationSuccess(identityId: String?, verificationID: String?) {
        let identity = identityId ?? "nil (string)"
        let verification = verificationID ?? "nil (string)"
        CAPLog.print("✅ [\(MetaMapCapacitorPlugin.TAG)] Flow completed (verificationSuccess): identityId=\(identity), verificationId=\(verification)")

        guard let call = self.pluginCall else {
            CAPLog.print("❌ PluginCall object was null in verificationSuccess. This should not happen.")
            return
        }

        let payload = buildResultPayload(identityId: identityId, verificationID: verificationID)
        self.notifyListeners(MetaMapCapacitorPlugin.EVENT_FLOW_COMPLETED, data: payload)
        call.resolve(payload)
        self.pluginCall = nil
    }

    public func verificationCancelled(identityId: String?, verificationID: String?) {
        let identity = identityId ?? "nil (string)"
        let verification = verificationID ?? "nil (string)"
        CAPLog.print("❌ [\(MetaMapCapacitorPlugin.TAG)] Flow abandoned or cancelled (verificationCancelled): identityId=\(identity), verificationId=\(verification)")

        guard let call = self.pluginCall else {
            CAPLog.print("❌ PluginCall object was null in verificationCancelled. This should not happen.")
            let payloadNoCall = buildResultPayload(identityId: identityId, verificationID: verificationID)
            self.notifyListeners(MetaMapCapacitorPlugin.EVENT_FLOW_ABANDONED, data: payloadNoCall)
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
        self.pluginCall = nil
    }
}