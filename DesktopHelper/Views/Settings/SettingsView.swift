import ServiceManagement
import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettings()
                .tabItem { Label("General", systemImage: "gearshape") }
            WeatherSettings()
                .tabItem { Label("Weather", systemImage: "cloud.sun") }
            CalendarSettings()
                .tabItem { Label("Calendar & Reminders", systemImage: "calendar") }
        }
        .frame(width: 460, height: 440)
        // 菜单栏 App 打开设置窗口时要手动激活，否则窗口会在别的 App 后面
        .onAppear { NSApp.activate() }
    }
}

private struct GeneralSettings: View {
    @Environment(EventKitService.self) private var eventKit
    @Environment(PanelController.self) private var panel
    @AppStorage(SettingsKey.calendarDays) private var calendarDays = 7
    @AppStorage(SettingsKey.dueSoonDays) private var dueSoonDays = 7
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        Form {
            Toggle("Launch at Login", isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { _, enabled in
                    do {
                        if enabled {
                            try SMAppService.mainApp.register()
                        } else {
                            try SMAppService.mainApp.unregister()
                        }
                    } catch {
                        launchAtLogin = SMAppService.mainApp.status == .enabled
                    }
                }
            Stepper("Show calendar for next \(calendarDays) days", value: $calendarDays, in: 1...30)
                .onChange(of: calendarDays) { Task { await eventKit.refresh() } }
            Stepper("Due Soon: within \(dueSoonDays) days", value: $dueSoonDays, in: 1...30)
            Slider(value: Binding(get: { panel.blurRadius }, set: { panel.blurRadius = $0 }), in: 0...80) {
                Text("Background Blur")
            } minimumValueLabel: {
                Text("Clear").font(.caption)
            } maximumValueLabel: {
                Text("Frosted").font(.caption)
            }
        }
        .formStyle(.grouped)
    }
}

private struct WeatherSettings: View {
    @Environment(WeatherService.self) private var weather
    @AppStorage(SettingsKey.weatherUseLocation) private var useLocation = true
    @AppStorage(SettingsKey.weatherCityName) private var cityName = ""
    @AppStorage(SettingsKey.temperatureUnit) private var unit = TemperatureUnit.celsius.rawValue

    @State private var query = ""
    @State private var results: [GeoPlace] = []
    @State private var searchError: String?

    var body: some View {
        Form {
            Toggle("Use Current Location", isOn: $useLocation)
                .onChange(of: useLocation) { refresh() }
            Picker("Temperature Unit", selection: $unit) {
                ForEach(TemperatureUnit.allCases) { Text($0.label).tag($0.rawValue) }
            }
            .onChange(of: unit) { refresh() }

            Section(useLocation ? "Fallback City (used if location fails)" : "City") {
                LabeledContent("Current", value: cityName.isEmpty ? "Not set" : cityName)
                HStack {
                    TextField("Search city", text: $query)
                        .onSubmit(search)
                    Button("Search", action: search)
                }
                if let searchError {
                    Text(searchError).foregroundStyle(.red)
                }
                ForEach(results) { place in
                    Button {
                        weather.setCity(place)
                        results = []
                        query = ""
                    } label: {
                        VStack(alignment: .leading) {
                            Text(place.name)
                            Text(place.subtitle).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .formStyle(.grouped)
    }

    private func refresh() {
        Task { await weather.refresh() }
    }

    private func search() {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return }
        Task {
            do {
                results = try await WeatherService.searchPlaces(q)
                searchError = results.isEmpty ? "No results" : nil
            } catch {
                searchError = error.localizedDescription
            }
        }
    }
}

private struct CalendarSettings: View {
    @Environment(EventKitService.self) private var eventKit

    var body: some View {
        Form {
            Section("Show These Calendars") {
                if eventKit.eventCalendars.isEmpty {
                    Text("No calendars, or no access").foregroundStyle(.secondary)
                }
                ForEach(eventKit.eventCalendars) { toggle(for: $0) }
            }
            Section("Show These Reminder Lists") {
                if eventKit.reminderLists.isEmpty {
                    Text("No reminder lists, or no access").foregroundStyle(.secondary)
                }
                ForEach(eventKit.reminderLists) { toggle(for: $0) }
            }
            Section("Quick Add") {
                Picker("Add new to-dos to", selection: Binding(
                    get: { eventKit.defaultReminderListID ?? "" },
                    set: { eventKit.defaultReminderListID = $0.isEmpty ? nil : $0 }
                )) {
                    Text("Default List").tag("")
                    ForEach(eventKit.reminderLists) { Text($0.title).tag($0.id) }
                }
            }
        }
        .formStyle(.grouped)
    }

    private func toggle(for source: CalendarSource) -> some View {
        Toggle(isOn: Binding(
            get: { !eventKit.hiddenCalendarIDs.contains(source.id) },
            set: { show in
                if show {
                    eventKit.hiddenCalendarIDs.remove(source.id)
                } else {
                    eventKit.hiddenCalendarIDs.insert(source.id)
                }
            }
        )) {
            HStack {
                Circle().fill(source.color).frame(width: 8, height: 8)
                Text(source.title)
                Text(source.sourceTitle).font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}
