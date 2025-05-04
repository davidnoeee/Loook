//
//  SettingsView.swift
//  loook
//
//  Created by David Noé on 04.05.2025.
//


import SwiftUI

struct SettingsView: View {
    @ObservedObject var reminderManager: ReminderManager
    @Binding var isPresented: Bool
    @State private var selectedTab = 0
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        VStack(spacing: 12) {
            // Header with title and close button
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
            
            ScrollView {
                VStack(spacing: 8) {
                    // General Settings Card
                    SettingsCard {
                        VStack(spacing: 10) {
                            HStack {
                                Text("General")
                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                                    .foregroundStyle(.secondary)
                                    .padding(.leading, 2)
                                Spacer()
                            }
                            .padding(.bottom, 2)
                            
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
                    
                    // Intervals Settings Card
                    SettingsCard {
                        VStack(spacing: 14) {
                            HStack {
                                Text("Reminder Intervals")
                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                                    .foregroundStyle(.secondary)
                                    .padding(.leading, 2)
                                Spacer()
                            }
                            .padding(.bottom, 2)
                            
                            SettingsSlider(
                                title: "Blink",
                                value: $reminderManager.blinkReminderInterval,
                                range: 15...600,
                                step: reminderManager.blinkReminderInterval < 60 ? 15 : 60,
                                formatter: { value in
                                    value < 60 ? "\(Int(value))s" : "\(Int(value/60))m"
                                }
                            )
                            .onChange(of: reminderManager.blinkReminderInterval) { _ in
                                reminderManager.startTimers()
                                reminderManager.resetPopups()
                            }
                            
                            SettingsSlider(
                                title: "Posture",
                                value: $reminderManager.postureReminderInterval,
                                range: 300...1800,
                                step: 300,
                                formatter: { value in "\(Int(value/60))m" }
                            )
                            .onChange(of: reminderManager.postureReminderInterval) { _ in
                                reminderManager.startTimers()
                                reminderManager.resetPopups()
                            }
                            
                            SettingsSlider(
                                title: "Distance Focus",
                                value: $reminderManager.distanceFocusReminderInterval,
                                range: 300...1800,
                                step: 300,
                                formatter: { value in "\(Int(value/60))m" }
                            )
                            .onChange(of: reminderManager.distanceFocusReminderInterval) { _ in
                                reminderManager.startTimers()
                                reminderManager.resetPopups()
                            }
                        }
                    }
                    
                    // Preview Card
                    SettingsCard {
                        VStack(spacing: 10) {
                            HStack {
                                Text("Preview")
                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                                    .foregroundStyle(.secondary)
                                    .padding(.leading, 2)
                                Spacer()
                            }
                            .padding(.bottom, 2)
                            
                            HStack(spacing: 8) {
                                PreviewButton(title: "Blink", icon: "eye") {
                                    reminderManager.resetPopups()
                                    reminderManager.testBlinkReminder()
                                }
                                
                                PreviewButton(title: "Posture", icon: "arrow.up") {
                                    reminderManager.resetPopups()
                                    reminderManager.testPostureReminder()
                                }
                                
                                PreviewButton(title: "Distance", icon: "timer") {
                                    reminderManager.resetPopups()
                                    reminderManager.testDistanceFocusReminder()
                                }
                            }
                        }
                    }
                    
                    // App Controls Card
                    SettingsCard {
                        VStack(spacing: 10) {
                            HStack {
                                Text("App Controls")
                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                                    .foregroundStyle(.secondary)
                                    .padding(.leading, 2)
                                Spacer()
                            }
                            .padding(.bottom, 2)
                            
                            HStack(spacing: 8) {
                                ActionButton(title: "Reset Reminders") {
                                    reminderManager.resetPopups()
                                }
                                
                                ActionButton(title: "Quit App", destructive: true) {
                                    NSApplication.shared.terminate(nil)
                                }
                            }
                        }
                    }
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
        .background(
            Material.ultraThickMaterial
                .opacity(0.95)
        )
        .environment(\.colorScheme, .dark)
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
                    .stroke(Color.black.opacity(0.2), lineWidth: 0.5)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
                    .padding(0.5)
            }
            .shadow(color: .black.opacity(0.15), radius: 3, x: 0, y: 2)
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
        }
        .toggleStyle(SwitchToggleStyle(tint: Color.blue))
    }
}

struct SettingsSlider: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let formatter: (Double) -> String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(.primary)
                
                Spacer()
                
                Text(formatter(value))
                    .font(.system(size: 14, weight: .regular, design: .rounded))
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 40, alignment: .trailing)
            }
            
            Slider(value: $value, in: range, step: step)
                .tint(.blue)
        }
    }
}

struct PreviewButton: View {
    var title: String
    var icon: String
    var action: () -> Void
    @State private var isPressed = false
    
    var body: some View {
        Button {
            action()
        } label: {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.blue)
                    .frame(height: 18)
                
                Text(title)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.primary)
            }
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isPressed ? Color.white.opacity(0.12) : Color.white.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
            )
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
}

struct ActionButton: View {
    var title: String
    var destructive: Bool = false
    var action: () -> Void
    @State private var isPressed = false
    
    var body: some View {
        Button {
            action()
        } label: {
            Text(title)
                .font(.system(size: 13.5, weight: .medium, design: .rounded))
                .foregroundStyle(destructive ? .red : .primary)
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
    
    // Break up the complex expression into computed properties
    private var backgroundRect: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(backgroundColor)
    }
    
    private var backgroundColor: Color {
        if isPressed {
            return destructive ? Color.red.opacity(0.15) : Color.white.opacity(0.12)
        } else {
            return destructive ? Color.red.opacity(0.07) : Color.white.opacity(0.05)
        }
    }
    
    private var overlayRect: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .stroke(destructive ? Color.red.opacity(0.2) : Color.white.opacity(0.1), lineWidth: 0.5)
    }
}
