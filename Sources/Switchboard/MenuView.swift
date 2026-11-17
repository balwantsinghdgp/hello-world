import AppKit
import ServiceManagement
import SwiftUI

struct MenuView: View {
    private enum Page: String, CaseIterable {
        case levers = "Levers"
        case presentation = "Presentation"
    }

    @EnvironmentObject private var store: LeverStore
    @EnvironmentObject private var session: PresentationSession
    @State private var page: Page = .levers
    @State private var query = ""

    var body: some View {
        VStack(spacing: 10) {
            presentationButton

            Picker("", selection: $page) {
                ForEach(Page.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            switch page {
            case .levers: leversPage
            case .presentation: PresentationSettingsView()
            }

            Divider()
            HStack {
                Text("Switchboard").foregroundStyle(.secondary)
                Spacer()
                Button("Quit") { NSApp.terminate(nil) }
                    .keyboardShortcut("q")
            }
            .font(.callout)
        }
        .padding(12)
        .frame(width: 340, height: 520)
        .onAppear { store.refresh() }
    }

    private var presentationButton: some View {
        Button {
            session.toggle()
        } label: {
            HStack {
                Image(systemName: session.isActive ? "stop.circle.fill" : "play.rectangle.fill")
                VStack(alignment: .leading, spacing: 1) {
                    Text(session.isActive ? "End Presentation Mode" : "Start Presentation Mode")
                        .fontWeight(.semibold)
                    Text(session.isActive ? "Your settings come back when you end it" : "Tidy the screen for sharing or recording")
                        .font(.caption)
                        .opacity(0.8)
                }
                Spacer()
            }
            .padding(10)
            .frame(maxWidth: .infinity)
            .foregroundStyle(Color.white)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(session.isActive ? Color.red : Color.accentColor)
            )
        }
        .buttonStyle(.plain)
    }

    private var leversPage: some View {
        VStack(spacing: 8) {
            TextField("Search", text: $query)
                .textFieldStyle(.roundedBorder)

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(LeverCategory.allCases, id: \.self) { category in
                        let items = levers(in: category)
                        if !items.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(category.rawValue)
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.secondary)
                                LazyVGrid(columns: [GridItem(.flexible(), spacing: 6), GridItem(.flexible())], spacing: 6) {
                                    ForEach(items) { lever in
                                        LeverTile(lever: lever, isOn: store.isOn(lever.id)) {
                                            store.trigger(lever)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private func levers(in category: LeverCategory) -> [Lever] {
        store.levers.filter { lever in
            lever.category == category
                && (query.isEmpty || lever.title.localizedCaseInsensitiveContains(query))
        }
    }
}

private struct LeverTile: View {
    let lever: Lever
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: lever.symbol)
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 26, height: 26)
                    .foregroundStyle(isOn ? Color.white : Color.primary)
                    .background(Circle().fill(isOn ? Color.accentColor : Color.primary.opacity(0.1)))
                Text(lever.title)
                    .font(.callout)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
            }
            .padding(8)
            .frame(maxWidth: .infinity, minHeight: 46)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(0.06)))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityValue(lever.isToggle ? (isOn ? "On" : "Off") : "")
    }
}

private struct PresentationSettingsView: View {
    @EnvironmentObject private var store: LeverStore
    @EnvironmentObject private var session: PresentationSession
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                section("When a session starts") {
                    ForEach(store.levers.filter { $0.presentationValue != nil }) { lever in
                        Toggle(label(for: lever), isOn: managedBinding(lever.id))
                    }
                    Toggle("Hide other apps", isOn: $session.hidesOtherApps)
                }

                section("Automatic") {
                    Toggle("Start when sharing or recording is detected", isOn: $session.autoDetect)
                    Text("Watches for these process names (comma-separated):")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("CptHost, screencaptureui", text: $session.watchedProcesses)
                        .textFieldStyle(.roundedBorder)
                        .disabled(!session.autoDetect)
                }

                section("General") {
                    Toggle("Launch at login", isOn: $launchAtLogin)
                        .onChange(of: launchAtLogin) { _, enabled in
                            setLaunchAtLogin(enabled)
                        }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
            content()
        }
    }

    /// Describes what the session will do, e.g. "Turn off Recent Apps in Dock".
    private func label(for lever: Lever) -> String {
        lever.presentationValue == true ? lever.title : "Turn off \(lever.title)"
    }

    private func managedBinding(_ id: String) -> Binding<Bool> {
        Binding(
            get: { session.managed.contains(id) },
            set: { included in
                if included { session.managed.insert(id) } else { session.managed.remove(id) }
            }
        )
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            // Only works from the bundled .app; reflect the real state.
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }
}
