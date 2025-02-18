import CashfreePGCoreSDK
import CashfreePGUISDK
import CashfreePG

@objc(CashfreePgApi)
class CashfreePgApi: NSObject {

    override init() {
        super.init()
    }

    @objc static func requiresMainQueueSetup() -> Bool {
        return false
    }

    @objc func doPayment(_ paymentObject: NSString) -> Void {
        do {
            let dropObject = try! parseDropPayment(paymentObject: "\(paymentObject)")
            if (dropObject != nil) {
                let vc = RCTPresentedViewController()
                try CFPaymentGatewayService.getInstance().doPayment(dropObject!, viewController: vc!)
            }
        }
        catch {
            print (error)
        }
    }

    @objc func setCallback() -> Void {
        CFPaymentGatewayService.getInstance().setCallback(self)
    }

    private func parseDropPayment(paymentObject: String) throws -> CFDropCheckoutPayment? {
        //        print(paymentObject)
        let data = paymentObject.data(using: .utf8)!
        if let output = try! JSONSerialization.jsonObject(with: data, options: .allowFragments) as? Dictionary<String, Any> {
            do {
                let session = getSession(paymentObject: output)
                let component = getComponents(paymentObject: output)
                let theme = getTheme(paymentObject: output)

                let nativePayment = try CFDropCheckoutPayment.CFDropCheckoutPaymentBuilder()
                    .setSession(session!)
                    .setTheme(theme!)
                    .setComponent(component!)
                    .build()
                nativePayment.setPlatform( "ios-rn-" + (((output["version"]) as? String) ?? ""))
                return nativePayment

            } catch let e {
                let error = e as! CashfreeError
                print(error.localizedDescription)
                // Handle errors here
            }
        }
        return nil
    }

    private func getSession(paymentObject: Dictionary<String,Any>) -> CFSession? {
        if let sessionDict = paymentObject["session"] as? Dictionary<String, String> {
            do {
                let builder =  CFSession.CFSessionBuilder()
                    .setOrderID(sessionDict["orderID"] ?? "")
                    .setOrderToken(sessionDict["token"] ?? "")
                if (sessionDict["environment"] == "SANDBOX") {
                    builder.setEnvironment(CFENVIRONMENT.SANDBOX)
                } else {
                    builder.setEnvironment(CFENVIRONMENT.PRODUCTION)
                }
                let session = try builder.build()
                return session
            } catch let e {
                let error = e as! CashfreeError
                print(error.localizedDescription)
                // Handle errors here
            }
        }
        return nil
    }

    private func getComponents(paymentObject: Dictionary<String,Any>) -> CFPaymentComponent? {
        if let components = paymentObject["components"] as? Array<String> {
            do {
                var array = ["order-details"]
                components.forEach { item in
                    let component = getItemName(item: item)
                    if (component != nil) {
                        array.append(component!)
                    }
                }
                let paymentComponents = try CFPaymentComponent.CFPaymentComponentBuilder()
                    .enableComponents(array)
                    .build()
                return paymentComponents
            } catch let e {
                let error = e as! CashfreeError
                print(error.localizedDescription)
                // Handle errors here
            }
        }
        return nil
    }

    private func getItemName(item: String) -> String? {
        switch item {
        case "CARD" :
            return "card"
        case "UPI" :
            return "upi"
        case "NB" :
            return "netbanking"
        case "WALLET" :
            return "wallet"
        case "EMI" :
            return "emi"
        case "PAY_LATER" :
            return "paylater"
        default :
            return nil
        }
    }

    private func getTheme(paymentObject: Dictionary<String,Any>) -> CFTheme? {
        if let theme = paymentObject["theme"] as? Dictionary<String, String> {
            do {
                return try CFTheme.CFThemeBuilder()
                    .setNavigationBarBackgroundColor(theme["navigationBarBackgroundColor"]!)
                    .setNavigationBarTextColor(theme["navigationBarTextColor"]!)
                    .setButtonBackgroundColor(theme["buttonBackgroundColor"]!)
                    .setButtonTextColor(theme["buttonTextColor"]!)
                    .setPrimaryTextColor(theme["primaryTextColor"]!)
                    .setSecondaryTextColor(theme["secondaryTextColor"]!)
                    .build()
            } catch let e {
                let error = e as! CashfreeError
                print(error.localizedDescription)
                // Handle errors here
            }
            //            return CFTheme.CFThemeBuilder().build()
            //                .setNavigationBarBackgroundColor(theme["navigationBarBackgroundColor"] ?? "")
        }
        return nil
    }

    func stringify(json: Any) -> String {
        var options: JSONSerialization.WritingOptions = []
        do {
          let data = try JSONSerialization.data(withJSONObject: json, options: options)
          if let string = String(data: data, encoding: String.Encoding.utf8) {
            return string
          }
        } catch {
          print(error)
        }

        return ""
    }
}

extension CashfreePgApi: CFResponseDelegate {
    func onError(_ error: CFErrorResponse, order_id: String) {
        print(error.message)
        let data : [String: String] = ["status": error.status ?? ""
                                       , "message": error.message ?? ""
                                       , "code": error.code ?? ""
                                       , "type": error.type ?? ""]
        var body:[String: String] = ["error": stringify(json: data), "orderID": order_id]
        CashfreeEmitter.sharedInstance.dispatch(name: "cfFailure", body: stringify(json: body))
    }

    func verifyPayment(order_id: String) {
        print(order_id)
        CashfreeEmitter.sharedInstance.dispatch(name: "cfSuccess", body: order_id)
    }
}
