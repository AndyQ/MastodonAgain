import Everything
import Mastodon
import SwiftUI
import WebKit

struct AuthorizationFlow: View {
    @EnvironmentObject
    var appModel: AppModel

    let hosts = [
        Instance("mastodon.social"),
        Instance("mastodon.online")
    ]

    @State
    var authorizationCode: String = ""

    @State
    var clientName = "MastodonAgain"

    @State
    var website = "https://schwa.io/MastodonAgain"

    @State
    var spinning = false

    @State
    var date: Date?

    var body: some View {
        Group {
            if spinning {
                ProgressView()
                if let date {
                    Text("Waiting for token: ") + Text(date, style: .relative).monospacedDigit()
                }
            }
            else {
                switch appModel.authorization {
                case .unauthorized:
                    unauthorizedView
                case .registered(let application):
                    registeredView(application)
                default:
                    Text("Already authorized!")
                }
            }
        }
        .onChange(of: appModel.authorization) { authorization in
            appLogger?.log("Authorization changed: \(String(describing: authorization))")
        }
        .toolbar {
            Button("Cancel Authorization") {
                appModel.authorization = .unauthorized
            }
        }
    }

    @ViewBuilder
    var unauthorizedView: some View {
        GroupBox("Login") {
            Picker("Host", selection: $appModel.instance) {
                ForEach(hosts, id: \.self) { instance in
                    Text(verbatim: instance.host).tag(instance)
                }
            }
//            TextField("Host", text: $appModel.instance.host)
            GroupBox("Application") {
                Group {
                    TextField("Application Name", text: $clientName)
                    TextField("Website", text: $website)
                }
                Button("Register Application") {
                    Task {
                        try await register()
                    }
                }
            }
        }
        .frame(maxWidth: 320)
    }

    @ViewBuilder
    func registeredView(_ application: RegisteredApplication) -> some View {
        let url = URL(string: "https://\(appModel.instance.host)/oauth/authorize?client_id=\(application.clientID)&scope=read+write+follow+push&redirect_uri=urn:ietf:wg:oauth:2.0:oob&response_type=code")!
        let request = URLRequest(url: url)
        ViewAdaptor {
            let webConfiguration = WKWebViewConfiguration()
            let view = WKWebView(frame: .zero, configuration: webConfiguration)
            view.load(request)
            return view
        } update: { _ in
        }
        Image(systemName: "arrow.down").font(.largeTitle)
            .foregroundColor(.red)
            .padding()
        TextField("Authorisation Code", text: $authorizationCode)
            .onSubmit {
                Task {
                    try await getToken(with: application)
                }
            }
            .padding()
    }

    func register() async throws {
        appLogger?.log("Registering")
        let url = URL(string: "https://\(appModel.instance.host)/api/v1/apps")!
        let request = URLRequest(url: url, formParameters: [
            "client_name": clientName,
            "redirect_uris": "urn:ietf:wg:oauth:2.0:oob",
            "scopes": "read write follow push",
            "website": website,
        ])

        let (application, _) = try await URLSession.shared.json(RegisteredApplication.self, for: request)
        appModel.authorization = .registered(application)
    }

    func getToken(with application: RegisteredApplication) async throws {
        self.spinning = true
        self.date = .now
        appLogger?.log("Getting Token")
        let url = URL(string: "https://\(appModel.instance.host)/oauth/token")!
        let request = URLRequest(url: url, formParameters: [
            "client_id": application.clientID,
            "client_secret": application.clientSecret,
            "redirect_uri": "urn:ietf:wg:oauth:2.0:oob",
            "grant_type": "authorization_code",
            "code": authorizationCode,
            "scope": "read write follow push",
        ])
        let (token, _) = try await URLSession.shared.json(Token.self, for: request)
        appModel.authorization = .authorized(application, token)
    }
}
