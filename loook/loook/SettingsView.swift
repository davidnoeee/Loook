import SwiftUI

struct SettingsView: View {
    @ObservedObject var reminderManager: ReminderManager
    @Binding var isPresented: Bool
    
    // System colors that adapt to light/dark mode
    private let accentBlue = Color.blue
    private let accentRed = Color.red
    
    var body: some View {
        VStack(spacing: 12) {
            // Header
            HeaderView(isPresented: $isPresented)
            
            ScrollView {
                VStack(spacing: 8) {
                    // General Settings Card
                    GeneralSettingsCard(reminderManager: reminderManager)
                    
                    // Intervals Settings Card
                    IntervalsSettingsCard(reminderManager: reminderManager)
                    
                    // Preview Card
                    PreviewCard(reminderManager: reminderManager)
                    
                    // App Controls Card
                    AppControlsCard(
                        reminderManager: reminderManager,
                        accentBlue: accentBlue,
                        accentRed: accentRed
                    )
                }
                .padding(.horizontal, 12)
            }
            .scrollIndicators(.hidden)
            .scrollClipDisabled()
            .frame(width: 320)
            
            // Version footer
            Text("Loook v1.0")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
                .padding(.bottom, 10)
                .padding(.top, -4)
        }
        .frame(width: 320)
        .fixedSize(horizontal: false, vertical: true)
        //.background(Material.thin.opacity(0.95))
        //.environment(\.colorScheme, .dark)
    }
}

// MARK: - Header Component
struct HeaderView: View {
    @Binding var isPresented: Bool
    
    var body: some View {
        HStack {
            Text("Loook Settings")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
            
            Spacer()
            
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                    isPresented = false
                }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.secondary)
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 4)
    }
}

// MARK: - General Settings Card
struct GeneralSettingsCard: View {
    @ObservedObject var reminderManager: ReminderManager
    
    var body: some View {
        SettingsCard {
            VStack(spacing: 10) {
                SectionHeader(title: "General")
                
                SettingsToggle(title: "Enable Reminders", isOn: $reminderManager.isRemindersEnabled)
                    .onChange(of: reminderManager.isRemindersEnabled) { _ in
                        reminderManager.startTimers()
                    }
                
                SettingsToggle(title: "Launch at Login", isOn: $reminderManager.launchAtLogin)
                    .onChange(of: reminderManager.launchAtLogin) { _ in
                        reminderManager.toggleLaunchAtLogin()
                    }
            }
        }
    }
}

// MARK: - Intervals Settings Card
struct IntervalsSettingsCard: View {
    @ObservedObject var reminderManager: ReminderManager
    
    var body: some View {
        SettingsCard {
            VStack(spacing: 14) {
                SectionHeader(title: "Reminder Intervals")
                
                // Blink reminder
                BlinkReminderSection(reminderManager: reminderManager)
                
                // Posture reminder
                PostureReminderSection(reminderManager: reminderManager)
                
                // Look Away reminder (renamed from Distance Focus)
                LookAwayReminderSection(reminderManager: reminderManager)
            }
        }
    }
}

// MARK: - Blink Reminder Section
struct BlinkReminderSection: View {
    @ObservedObject var reminderManager: ReminderManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header with checkbox and value
            HStack {
                Toggle(isOn: $reminderManager.isBlinkReminderEnabled) {
                    Text("Blink")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(reminderManager.isBlinkReminderEnabled ? .primary : .secondary)
                }
                .toggleStyle(.checkbox)
                
                Spacer()
                
                Text(reminderManager.blinkReminderInterval < 60 ?
                     "\(Int(reminderManager.blinkReminderInterval))s" :
                     "\(Int(reminderManager.blinkReminderInterval/60))m")
                    .font(.system(size: 14, weight: .regular, design: .rounded))
                    .foregroundStyle(.secondary)
                    .opacity(reminderManager.isBlinkReminderEnabled ? 1.0 : 0.5)
                    .frame(minWidth: 40, alignment: .trailing)
                    .contentTransition(.numericText())
                    .animation(.spring, value: reminderManager.blinkReminderInterval)
            }
            .onChange(of: reminderManager.isBlinkReminderEnabled) { _ in
                reminderManager.startTimers()
            }
            
            // Controls
            HStack(spacing: 8) {
                // Segment picker
                BlinkSegmentPicker(reminderManager: reminderManager)
                
                // Slider
                SliderWithPreservedTint(
                    value: $reminderManager.blinkReminderInterval,
                    range: reminderManager.blinkReminderInterval < 60 ? 10...59 : 60...600,
                    step: reminderManager.blinkReminderInterval < 60 ? 5 : 60,
                    isDisabled: !reminderManager.isBlinkReminderEnabled
                )
                .onChange(of: reminderManager.blinkReminderInterval) { _ in
                    reminderManager.startTimers()
                    reminderManager.resetPopups()
                }
            }
        }
    }
}

// MARK: - Blink Segment Picker Helper
struct BlinkSegmentPicker: View {
    @ObservedObject var reminderManager: ReminderManager
    
    var body: some View {
        AnimatedSegmentPicker(
            selection: Binding(
                get: { reminderManager.blinkReminderInterval < 60 ? 0 : 1 },
                set: { newValue in
                    if newValue == 0 && reminderManager.blinkReminderInterval >= 60 {
                        reminderManager.blinkReminderInterval = 45
                    } else if newValue == 1 && reminderManager.blinkReminderInterval < 60 {
                        reminderManager.blinkReminderInterval = 60
                    }
                }
            ),
            options: ["Sec", "Min"],
            isDisabled: !reminderManager.isBlinkReminderEnabled
        )
        .frame(width: 120, height: 28)
    }
}

// MARK: - Posture Reminder Section
struct PostureReminderSection: View {
    @ObservedObject var reminderManager: ReminderManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Toggle(isOn: $reminderManager.isPostureReminderEnabled) {
                    Text("Posture")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(reminderManager.isPostureReminderEnabled ? .primary : .secondary)
                }
                .toggleStyle(.checkbox)
                
                Spacer()
                
                Text("\(Int(reminderManager.postureReminderInterval/60))m")
                    .font(.system(size: 14, weight: .regular, design: .rounded))
                    .foregroundStyle(.secondary)
                    .opacity(reminderManager.isPostureReminderEnabled ? 1.0 : 0.5)
                    .frame(minWidth: 40, alignment: .trailing)
                    .contentTransition(.numericText())
                    .animation(.spring, value: reminderManager.postureReminderInterval)
            }
            .onChange(of: reminderManager.isPostureReminderEnabled) { _ in
                reminderManager.startTimers()
            }
            
            SliderWithPreservedTint(
                value: $reminderManager.postureReminderInterval,
                range: 300...1800,
                step: 300,
                isDisabled: !reminderManager.isPostureReminderEnabled
            )
            .onChange(of: reminderManager.postureReminderInterval) { _ in
                reminderManager.startTimers()
                reminderManager.resetPopups()
            }
        }
    }
}

// MARK: - Look Away Reminder Section (Renamed from Distance Focus)
struct LookAwayReminderSection: View {
    @ObservedObject var reminderManager: ReminderManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Toggle(isOn: $reminderManager.isDistanceFocusReminderEnabled) {
                    Text("Look Away")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(reminderManager.isDistanceFocusReminderEnabled ? .primary : .secondary)
                }
                .toggleStyle(.checkbox)
                
                Spacer()
                
                Text("\(Int(reminderManager.distanceFocusReminderInterval/60))m")
                    .font(.system(size: 14, weight: .regular, design: .rounded))
                    .foregroundStyle(.secondary)
                    .opacity(reminderManager.isDistanceFocusReminderEnabled ? 1.0 : 0.5)
                    .frame(minWidth: 40, alignment: .trailing)
                    .contentTransition(.numericText())
                    .animation(.spring, value: reminderManager.distanceFocusReminderInterval)
            }
            .onChange(of: reminderManager.isDistanceFocusReminderEnabled) { _ in
                reminderManager.startTimers()
            }
            
            SliderWithPreservedTint(
                value: $reminderManager.distanceFocusReminderInterval,
                range: 300...1800,
                step: 300,
                isDisabled: !reminderManager.isDistanceFocusReminderEnabled
            )
            .onChange(of: reminderManager.distanceFocusReminderInterval) { _ in
                reminderManager.startTimers()
                reminderManager.resetPopups()
            }
        }
    }
}

// MARK: - Preview Card
struct PreviewCard: View {
    @ObservedObject var reminderManager: ReminderManager
    
    var body: some View {
        SettingsCard {
            VStack(spacing: 10) {
                SectionHeader(title: "Preview")
                
                HStack(spacing: 8) {
                    PreviewButton(
                        title: "Blink",
                        icon: "eye",
                        isDisabled: reminderManager.isAnyReminderShowing || !reminderManager.isBlinkReminderEnabled,
                        action: {
                            reminderManager.resetPopups()
                            reminderManager.testBlinkReminder()
                        }
                    )
                    
                    PreviewButton(
                        title: "Posture",
                        icon: "arrow.up",
                        isDisabled: reminderManager.isAnyReminderShowing || !reminderManager.isPostureReminderEnabled,
                        action: {
                            reminderManager.resetPopups()
                            reminderManager.testPostureReminder()
                        }
                    )
                    
                    PreviewButton(
                        title: "Look Away",
                        icon: "timer",
                        isDisabled: reminderManager.isAnyReminderShowing || !reminderManager.isDistanceFocusReminderEnabled,
                        action: {
                            reminderManager.resetPopups()
                            reminderManager.testDistanceFocusReminder()
                        }
                    )
                }
            }
        }
    }
}

// MARK: - App Controls Card
struct AppControlsCard: View {
    @ObservedObject var reminderManager: ReminderManager
    let accentBlue: Color
    let accentRed: Color
    
    var body: some View {
        SettingsCard {
            VStack(spacing: 10) {
                SectionHeader(title: "App Controls")
                
                // Reset Reminders button
                ActionButton(title: "Reset Reminders") {
                    reminderManager.resetPopups()
                }
                
                // Feedback & Quit App with custom colors
                HStack(spacing: 8) {
                    ActionButton(
                        title: "Feedback",
                        icon: "megaphone.fill",
                        customColor: accentBlue,
                        action: {
                            if let url = URL(string: "mailto:contact@ileb.zip?subject=Loook%20Feedback:%20") {
                                NSWorkspace.shared.open(url)
                            }
                        }
                    )
                    
                    ActionButton(
                        title: "Quit App",
                        icon: "rectangle.portrait.and.arrow.right",
                        customColor: accentRed,
                        destructive: true,
                        action: {
                            NSApplication.shared.terminate(nil)
                        }
                    )
                }
            }
        }
    }
}

// MARK: - Section Header Helper
struct SectionHeader: View {
    let title: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
                .padding(.leading, 2)
            Spacer()
        }
        .padding(.bottom, 2)
    }
}

// MARK: - Slider with Preserved Tint for Dark Mode
struct SliderWithPreservedTint: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let isDisabled: Bool
    
    var body: some View {
        Slider(value: $value, in: range, step: step)
            .opacity(isDisabled ? 0.5 : 1)
    }
}

// MARK: - Design System Components
struct SettingsCard<Content: View>: View {
    var content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
            .padding(.vertical, 12)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Material.regular)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.primary.opacity(0.15), lineWidth: 0.5)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.secondary.opacity(0.15), lineWidth: 0.5)
                    .padding(0.5)
            }
            .shadow(color: .black.opacity(0.15), radius: 3, x: 0, y: 2)
    }
}

// Animated Segment Picker with sliding selection
struct AnimatedSegmentPicker: View {
    @Binding var selection: Int
    let options: [String]
    var isDisabled: Bool = false
    @Namespace private var namespace
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(0..<options.count, id: \.self) { index in
                ZStack {
                    if selection == index && !isDisabled {
                        RoundedRectangle(cornerRadius: 5)
                            .fill(Color.accentColor.opacity(0.8))
                            .matchedGeometryEffect(id: "SegmentBackground", in: namespace)
                            .shadow(color: .black.opacity(0.15), radius: 1, x: 0, y: 1)
                    }
                    
                    Text(options[index])
                        .font(.system(size: 12, weight: selection == index ? .medium : .regular))
                        .foregroundStyle(
                            isDisabled ? Color.secondary.opacity(0.5) :
                                (selection == index ? .white : Color.secondary)
                        )
                        .padding(.vertical, 4)
                        .frame(maxWidth: .infinity)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    if !isDisabled {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                            selection = index
                        }
                    }
                }
            }
        }
        .padding(2)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.secondary.opacity(isDisabled ? 0.04 : 0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.secondary.opacity(isDisabled ? 0.1 : 0.15), lineWidth: 0.5)
        )
        .opacity(isDisabled ? 0.7 : 1)
        .animation(.spring(response: 0.3), value: isDisabled) // Animate disabled state changes
    }
}

struct SettingsToggle: View {
    let title: String
    @Binding var isOn: Bool
    
    var body: some View {
        Toggle(isOn: $isOn) {
            Text(title)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .multilineTextAlignment(.leading)
        }
        .toggleStyle(SwitchToggleStyle())
    }
}

struct PreviewButton: View {
    var title: String
    var icon: String
    var isDisabled: Bool
    var action: () -> Void
    @State private var isPressed = false
    
    var body: some View {
        Button {
            if !isDisabled {
                action()
            }
        } label: {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(isDisabled ? Color.secondary.opacity(0.5) : Color.accentColor)
                    .frame(height: 18)
                
                Text(title)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(isDisabled ? Color.secondary.opacity(0.5) : .primary)
            }
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(
                        isDisabled ? Color.secondary.opacity(0.15) :
                            (isPressed ? Color.secondary.opacity(0.12) : Color.secondary.opacity(0.05))
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(
                        isDisabled ? Color.secondary.opacity(0.15) : Color.secondary.opacity(0.15),
                        lineWidth: 0.5
                    )
            )
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .disabled(isDisabled)
        .scaleEffect((isPressed && !isDisabled) ? 0.96 : 1)
        .animation(.spring(response: 0.3), value: isDisabled)
        .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isPressed)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isDisabled {
                        isPressed = true
                    }
                }
                .onEnded { _ in
                    if !isDisabled {
                        isPressed = false
                        action()
                    }
                }
        )
    }
}

struct ActionButton: View {
    var title: String
    var icon: String? = nil
    var customColor: Color? = nil
    var destructive: Bool = false
    var action: () -> Void
    @State private var isPressed = false
    
    var body: some View {
        Button {
            action()
        } label: {
            HStack(spacing: 6) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(
                            customColor != nil ? customColor! :
                            destructive ? Color.red : Color.primary
                        )
                }
                
                Text(title)
                    .font(.system(size: 13.5, weight: .medium, design: .rounded))
                    .foregroundStyle(
                        customColor != nil ? customColor! :
                        destructive ? Color.red : Color.primary
                    )
            }
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(backgroundRect)
            .overlay(overlayRect)
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .scaleEffect(isPressed ? 0.96 : 1)
        .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isPressed)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in
                    isPressed = false
                    action()
                }
        )
    }
    
    private var backgroundRect: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(backgroundColor)
    }
    
    private var backgroundColor: Color {
        if let customColor = customColor {
            return isPressed ? customColor.opacity(0.15) : customColor.opacity(0.07)
        } else if destructive {
            return isPressed ? Color.red.opacity(0.15) : Color.red.opacity(0.07)
        } else {
            return isPressed ? Color.secondary.opacity(0.12) : Color.secondary.opacity(0.05)
        }
    }
    
    private var overlayRect: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .stroke(
                customColor != nil ? customColor!.opacity(0.25) :
                destructive ? Color.red.opacity(0.25) : Color.secondary.opacity(0.15),
                lineWidth: 0.5
            )
    }
}

// Extension for computed property only
extension ReminderManager {
    var isAnyReminderShowing: Bool {
        return showArrowReminder || showEyeReminder || showCountdownReminder || isShowingReminder
    }
}
