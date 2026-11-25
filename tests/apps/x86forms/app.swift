// x86forms: forms and controls for the agent tools (tests/ax/actions_e2e.py: type into a tapped field, fill, drag,
// set_value, expect, batch; app_state / launch errors). The screen comes from the launch arguments:
//   (none) / form   text fields: placeholders only ("Email"), a label beside a field without a placeholder ("Name",
//                   "City"), a secure field ("Password"), a field far down (scrolled into view), a Sign Up button
//   controls        a slider (0-100), a switch, a stepper (0-10), a segmented control, a wheel picker, two date
//                   pickers (wheels, date and time), each value shown in a text with an identifier
//   list            a list whose rows reorder by drag (edit mode's handles) and a box that takes a dropped item
//   --exit-early    exits with status 3 right after launch (app_launch must say the app died)
//   --abort-reason  calls abort_with_reason after a second (the reason must reach app_logs / app_state)
// Each change is logged as an X86TEST line and shown on screen.
import SwiftUI
import UIKit
import UniformTypeIdentifiers

final class Model: ObservableObject {
    @Published var name = ""
    @Published var email = ""
    @Published var password = ""
    @Published var city = ""
    @Published var notes = ""
    @Published var submitted = "not yet"
    @Published var volume = 20.0
    @Published var wifi = false
    @Published var count = 2
    @Published var size = "Medium"
    @Published var fruit = "Apple"
    @Published var day = DateComponents(calendar: .current, year: 2026, month: 1, day: 15).date!
    @Published var alarm = DateComponents(calendar: .current, year: 2026, month: 1, day: 15, hour: 7, minute: 30).date!
    @Published var rows = ["Alpha", "Bravo", "Charlie", "Delta", "Echo"]
    @Published var dropped = "nothing"
}

func ymd(_ d: Date) -> String {
    let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "yyyy-MM-dd"; return f.string(from: d)
}
func hm(_ d: Date) -> String {
    let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "HH:mm"; return f.string(from: d)
}

struct FormScreen: View {
    @ObservedObject var m: Model
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Sign up").font(.title)
                HStack {
                    Text("Name").frame(width: 70, alignment: .leading)
                    TextField("", text: $m.name).textFieldStyle(.roundedBorder).accessibilityIdentifier("name-field")
                }
                TextField("Email", text: $m.email).textFieldStyle(.roundedBorder).keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                SecureField("Password", text: $m.password).textFieldStyle(.roundedBorder)
                HStack {
                    Text("City").frame(width: 70, alignment: .leading)
                    TextField("", text: $m.city).textFieldStyle(.roundedBorder)
                }
                Text("name=\(m.name) email=\(m.email) password=\(m.password.count) city=\(m.city)").accessibilityIdentifier("form-state")
                Color.clear.frame(height: 700)
                TextField("Notes", text: $m.notes).textFieldStyle(.roundedBorder)
                    .onSubmit { X86Test.log("notes-submit", true, m.notes) }
                Button("Sign Up") {
                    m.submitted = "name=\(m.name) email=\(m.email) password=\(m.password.count) city=\(m.city) notes=\(m.notes)"
                    X86Test.log("signup", true, m.submitted)
                }
                Text("submitted: \(m.submitted)").accessibilityIdentifier("submitted")
            }.padding()
        }
    }
}

struct ControlsScreen: View {
    @ObservedObject var m: Model
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                Slider(value: $m.volume, in: 0...100) { Text("Volume") }.accessibilityIdentifier("volume")
                Text("volume=\(Int(m.volume.rounded()))").accessibilityIdentifier("volume-state")
                Toggle("Wi-Fi", isOn: $m.wifi)
                Text("wifi=\(m.wifi ? "on" : "off")").accessibilityIdentifier("wifi-state")
                Stepper("Count: \(m.count)", value: $m.count, in: 0...10)
                Text("count=\(m.count)").accessibilityIdentifier("count-state")
                Picker("Size", selection: $m.size) {
                    ForEach(["Small", "Medium", "Large"], id: \.self) { Text($0) }
                }.pickerStyle(.segmented)
                Text("size=\(m.size)").accessibilityIdentifier("size-state")
                Picker("Fruit", selection: $m.fruit) {
                    ForEach(["Apple", "Banana", "Cherry", "Grape", "Mango", "Orange", "Peach"], id: \.self) { Text($0) }
                }.pickerStyle(.wheel).frame(height: 120).accessibilityIdentifier("fruit")
                Text("fruit=\(m.fruit)").accessibilityIdentifier("fruit-state")
                DatePicker("Day", selection: $m.day, displayedComponents: .date).datePickerStyle(.wheel).frame(height: 120)
                    .accessibilityIdentifier("day")
                Text("day=\(ymd(m.day))").accessibilityIdentifier("day-state")
                DatePicker("Alarm", selection: $m.alarm, displayedComponents: .hourAndMinute).datePickerStyle(.wheel).frame(height: 120)
                    .accessibilityIdentifier("alarm")
                Text("alarm=\(hm(m.alarm))").accessibilityIdentifier("alarm-state")
            }.padding()
        }
        .onChange(of: m.volume) { _, v in X86Test.log("volume", true, "\(Int(v.rounded()))") }
        .onChange(of: m.wifi) { _, v in X86Test.log("wifi", true, v ? "on" : "off") }
        .onChange(of: m.count) { _, v in X86Test.log("count", true, "\(v)") }
        .onChange(of: m.size) { _, v in X86Test.log("size", true, v) }
        .onChange(of: m.fruit) { _, v in X86Test.log("fruit", true, v) }
        .onChange(of: m.day) { _, v in X86Test.log("day", true, ymd(v)) }
        .onChange(of: m.alarm) { _, v in X86Test.log("alarm", true, hm(v)) }
    }
}

struct ListScreen: View {
    @ObservedObject var m: Model
    var body: some View {
        VStack(spacing: 0) {
            List {
                ForEach(m.rows, id: \.self) { r in Text(r) }
                    .onMove { from, to in
                        m.rows.move(fromOffsets: from, toOffset: to)
                        X86Test.log("reorder", true, m.rows.joined(separator: ","))
                    }
            }
            .environment(\.editMode, .constant(.active))
            .frame(height: 330)
            Text("order=\(m.rows.joined(separator: ","))").accessibilityIdentifier("order-state").padding(4)
            HStack(spacing: 20) {
                Text("Parcel").padding(14).background(Color.orange.opacity(0.5)).cornerRadius(8)
                    .draggable("Parcel")
                Text("Drop box: \(m.dropped)").frame(width: 190, height: 110).background(Color.blue.opacity(0.2)).cornerRadius(8)
                    .accessibilityIdentifier("dropbox")
                    .dropDestination(for: String.self) { items, _ in
                        m.dropped = items.joined(separator: ",")
                        X86Test.log("drop", true, m.dropped)
                        return true
                    }
            }.padding()
            Spacer()
        }
    }
}

struct Root: View {
    @StateObject var m = Model()
    let screen: String
    var body: some View {
        Group {
            switch screen {
            case "controls": ControlsScreen(m: m)
            case "list": ListScreen(m: m)
            default: FormScreen(m: m)
            }
        }
        .onAppear { X86Test.log("start-ui", true, screen) }
    }
}

@main
struct X86FormsApp: App {
    let screen: String
    init() {
        X86Test.reset()
        let args = ProcessInfo.processInfo.arguments
        screen = ["controls", "list", "form"].first(where: { args.contains($0) }) ?? "form"
        if args.contains("--exit-early") {
            X86Test.log("exit-early", true)
            exit(3)
        }
        if args.contains("--abort-reason") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                typealias F = @convention(c) (UInt32, UInt64, UnsafePointer<CChar>, UInt64) -> Void
                let h = dlopen(nil, RTLD_NOW)
                guard let sym = dlsym(h, "abort_with_reason") else { X86Test.log("abort-reason", false, "no abort_with_reason"); return }
                X86Test.log("abort-reason", true, "calling")
                // namespace 1 (OS_REASON_JETSAM-free user reason: 1 is "test"), code 42
                unsafeBitCast(sym, to: F.self)(1, 42, "x86forms test abort: the reason agents should see", 0)
            }
        }
    }
    var body: some Scene { WindowGroup { Root(screen: screen) } }
}
