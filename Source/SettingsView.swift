import AppKit
import ServiceManagement
import SwiftUI
import UserNotifications

struct SettingsView: View {
    @Bindable var model: AppModel

    @AppStorage(UserDefaultsKey.shouldPlayOnLaunch) private var playOnLaunch = false
    @AppStorage(UserDefaultsKey.notificationsEnabled) private var notificationsEnabled = false
    @AppStorage(UserDefaultsKey.apiChannelsSortOrder) private var sortOrderRaw = ChannelsSortOrder.default.rawValue
    @AppStorage(UserDefaultsKey.trackAction) private var trackActionRaw = TrackAction.google.rawValue
    @AppStorage(UserDefaultsKey.showsRecentStations) private var showsRecentStations = true
    @AppStorage(UserDefaultsKey.menuBarLeftClick) private var leftClickRaw = MenuBarClickAction.openMenu.rawValue
    @AppStorage(UserDefaultsKey.settingsPane) private var selectedPane = 0

    var body: some View {
        TabView(selection: $selectedPane) {
            Form {
                Toggle("Start at login", isOn: startAtLoginBinding)

                if let loginItemMessage = model.loginItemMessage {
                    warning(loginItemMessage)
                }

                if model.loginItemStatus == .requiresApproval {
                    Button("Open Login Items…") {
                        model.openLoginItemsSettings()
                    }
                }

                Toggle("Play on launch", isOn: $playOnLaunch)
                Toggle("Track notifications", isOn: $notificationsEnabled)

                if let notificationStatusText {
                    warning(notificationStatusText)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            .tag(0)
            .tabItem {
                Label("General", systemImage: "gearshape")
            }

            Form {
                Picker("Left click menu bar icon:", selection: $leftClickRaw) {
                    ForEach(MenuBarClickAction.allCases) { action in
                        Text(action.title).tag(action.rawValue)
                    }
                }

                Picker("Clicking a track:", selection: $trackActionRaw) {
                    ForEach(TrackAction.allCases) { action in
                        Text(action.title).tag(action.rawValue)
                    }
                }

                Picker("Station order:", selection: $sortOrderRaw) {
                    ForEach(ChannelsSortOrder.allCases) { order in
                        Text(order.title).tag(order.rawValue)
                    }
                }
                Toggle("Show recent stations", isOn: $showsRecentStations)
            }
            .fixedSize(horizontal: false, vertical: true)
            .tag(1)
            .tabItem {
                Label("Stations", systemImage: "radio")
            }

            Form {
                Section("SomaFM miniplayer") {
                    LabeledContent("Version", value: versionText)
                    LabeledContent("Source code") {
                        Link(
                            "GitHub repository",
                            destination: URL(string: "https://github.com/ealeksandrov/SomaFM-miniplayer")!
                        )
                    }
                }

                Section {
                    LabeledContent("Website") {
                        Link("somafm.com", destination: URL(string: "https://somafm.com/")!)
                    }
                    LabeledContent("Donate") {
                        Link("Support SomaFM", destination: URL(string: "https://somafm.com/support/")!)
                    }
                } header: {
                    Text("SomaFM Internet Radio")
                } footer: {
                    Text("All music is streamed by SomaFM, listener-supported internet radio.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)
            .fixedSize(horizontal: false, vertical: true)
            .tag(2)
            .tabItem {
                Label("About", systemImage: "info.circle")
            }
        }
        .formStyle(.columns)
        .pickerStyle(.menu)
        .toggleStyle(.checkbox)
        .scenePadding()
        .frame(width: 400)
        .onAppear {
            _ = NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)
        }
        .onDisappear {
            _ = NSApp.setActivationPolicy(.accessory)
        }
        .task {
            await model.refreshSystemSettings()
        }
        .onChange(of: sortOrderRaw) {
            model.settingsDidChange()
        }
        .onChange(of: leftClickRaw) {
            model.settingsDidChange()
        }
        .onChange(of: notificationsEnabled) { _, enabled in
            Task { await model.notificationPreferenceChanged(enabled: enabled) }
        }
    }

    private var startAtLoginBinding: Binding<Bool> {
        Binding {
            model.loginItemStatus == .enabled || model.loginItemStatus == .requiresApproval
        } set: { enabled in
            model.setStartAtLogin(enabled)
        }
    }

    private var notificationStatusText: String? {
        guard notificationsEnabled else { return nil }

        return switch model.notificationAuthorizationStatus {
        case .denied:
            "Notifications are disabled in System Settings."
        case .authorized, .provisional, .ephemeral, .notDetermined:
            nil
        @unknown default:
            "Notification status is unavailable."
        }
    }

    private func warning(_ message: String) -> some View {
        Label {
            Text(message)
        } icon: {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.yellow)
                .offset(x: 2)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    private var versionText: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
        return "\(version) (\(build))"
    }
}
