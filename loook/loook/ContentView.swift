import SwiftUI
import ServiceManagement

struct ContentView: View {
    @StateObject private var reminderManager = ReminderManager()
    @State private var showSettings = false
    
    var body: some View {
        VStack {
            if reminderManager.showArrowReminder {
                PostureReminderView(isShowing: $reminderManager.showArrowReminder)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .offset(y: -20)),
                        removal: .opacity.combined(with: .offset(y: -40))
                    ))
            }
            
            if reminderManager.showEyeReminder {
                BlinkReminderView(isShowing: $reminderManager.showEyeReminder)
                    .transition(.scale.combined(with: .opacity))
            }
            
            if reminderManager.showCountdownReminder {
                CountdownReminderView(
                    isShowing: $reminderManager.showCountdownReminder,
                    secondsRemaining: $reminderManager.countdownSeconds
                )
                .transition(.opacity)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
        .sheet(isPresented: $showSettings) {
            SettingsView(reminderManager: reminderManager)
                .frame(width: 400, height: 320)
        }
        .onAppear {
            reminderManager.startTimers()
        }
        .overlay(alignment: .topTrailing) {
            Button {
                showSettings.toggle()
            } label: {
                Image(systemName: "gear")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                    .padding()
            }
            .buttonStyle(.plain)
            .keyboardShortcut(",", modifiers: .command)
        }
    }
}

// Reminder Manager to handle all timers and states
class ReminderManager: ObservableObject {
    @Published var showArrowReminder = false
    @Published var showEyeReminder = false
    @Published var showCountdownReminder = false
    @Published var countdownSeconds = 20
    
    @Published var postureReminderInterval: TimeInterval = 10 * 60 // 10 minutes
    @Published var blinkReminderInterval: TimeInterval = 3 * 60 // 3 minutes
    @Published var countdownReminderInterval: TimeInterval = 20 * 60 // 20 minutes
    @Published var isRemindersEnabled = true
    @AppStorage("launchAtLogin") var launchAtLogin = false
    
    private var postureTimer: Timer?
    private var blinkTimer: Timer?
    private var countdownTimer: Timer?
    private var countdownProgressTimer: Timer?
    
    func startTimers() {
        stopAllTimers()
        
        if isRemindersEnabled {
            // Posture reminder timer
            postureTimer = Timer.scheduledTimer(withTimeInterval: postureReminderInterval, repeats: true) { [weak self] _ in
                guard let self = self else { return }
                self.showArrowReminder = true
                
                // Auto-dismiss after 3 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    withAnimation {
                        self.showArrowReminder = false
                    }
                }
            }
            
            // Blink reminder timer
            blinkTimer = Timer.scheduledTimer(withTimeInterval: blinkReminderInterval, repeats: true) { [weak self] _ in
                guard let self = self else { return }
                self.showEyeReminder = true
                
                // Auto-dismiss after 2 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    withAnimation {
                        self.showEyeReminder = false
                    }
                }
            }
            
            // Countdown reminder timer (20/20/20 rule)
            countdownTimer = Timer.scheduledTimer(withTimeInterval: countdownReminderInterval, repeats: true) { [weak self] _ in
                guard let self = self else { return }
                self.countdownSeconds = 20
                self.showCountdownReminder = true
                
                // Start the countdown progress timer
                self.countdownProgressTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] timer in
                    guard let self = self else { return }
                    if self.countdownSeconds > 0 {
                        self.countdownSeconds -= 1
                    } else {
                        timer.invalidate()
                        withAnimation {
                            self.showCountdownReminder = false
                        }
                    }
                }
            }
        }
    }
    
    func stopAllTimers() {
        postureTimer?.invalidate()
        blinkTimer?.invalidate()
        countdownTimer?.invalidate()
        countdownProgressTimer?.invalidate()
    }
    
    func toggleLaunchAtLogin() {
        let bundleId = Bundle.main.bundleIdentifier ?? ""
        
        if launchAtLogin {
            try? SMAppService.mainApp.register()
        } else {
            try? SMAppService.mainApp.unregister()
        }
    }
}

// Posture Reminder View (Arrow in Pill)
struct PostureReminderView: View {
    @Binding var isShowing: Bool
    @State private var arrowOffset: CGFloat = 0
    
    var body: some View {
        ZStack {
            // Pill background
            Capsule()
                .fill(.ultraThinMaterial)
                .frame(width: 100, height: 160)
                .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
            
            // Circle with arrow
            ZStack {
                Circle()
                    .fill(.white)
                    .frame(width: 70, height: 70)
                
                Image(systemName: "arrow.up")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundColor(.black)
                    .offset(y: arrowOffset)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatCount(1, autoreverses: false)) {
                arrowOffset = -20
            }
        }
    }
}

// Blink Reminder View (Eye in Circle)
struct BlinkReminderView: View {
    @Binding var isShowing: Bool
    @State private var scale: CGFloat = 0.5
    
    var body: some View {
        ZStack {
            // Circle background
            Circle()
                .fill(.ultraThinMaterial)
                .frame(width: 100, height: 100)
                .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
            
            // Circle with eye
            ZStack {
                Circle()
                    .fill(.white)
                    .frame(width: 80, height: 80)
                    .scaleEffect(scale)
                
                Image(systemName: "eye")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundColor(.black)
                    .scaleEffect(scale)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.6, blendDuration: 0)) {
                scale = 1.0
            }
        }
    }
}

// Countdown Reminder View
struct CountdownReminderView: View {
    @Binding var isShowing: Bool
    @Binding var secondsRemaining: Int
    @State private var isHovering = false
    
    var body: some View {
        ZStack {
            // Horizontal pill
            Capsule()
                .fill(.ultraThinMaterial)
                .frame(width: 140, height: 60)
                .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
            
            // Countdown text
            Text("\(secondsRemaining)s")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.primary)
            
            // Dismiss button (only visible on hover)
            if isHovering {
                VStack {
                    Button {
                        withAnimation {
                            isShowing = false
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .padding(4)
                    .offset(y: -24)
                }
            }
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovering = hovering
            }
        }
    }
}

// Settings View
struct SettingsView: View {
    @ObservedObject var reminderManager: ReminderManager
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Settings")
                .font(.title)
                .fontWeight(.bold)
            
            VStack(alignment: .leading, spacing: 15) {
                Toggle("Enable Reminders", isOn: $reminderManager.isRemindersEnabled)
                    .onChange(of: reminderManager.isRemindersEnabled) { _ in
                        reminderManager.startTimers()
                    }
                
                Toggle("Launch at Login", isOn: $reminderManager.launchAtLogin)
                    .onChange(of: reminderManager.launchAtLogin) { _ in
                        reminderManager.toggleLaunchAtLogin()
                    }
                
                Divider()
                
                VStack(alignment: .leading) {
                    Text("Posture Reminder: \(Int(reminderManager.postureReminderInterval/60)) minutes")
                    Slider(value: $reminderManager.postureReminderInterval, in: 60...3600, step: 60)
                        .onChange(of: reminderManager.postureReminderInterval) { _ in
                            reminderManager.startTimers()
                        }
                }
                
                VStack(alignment: .leading) {
                    Text("Blink Reminder: \(Int(reminderManager.blinkReminderInterval/60)) minutes")
                    Slider(value: $reminderManager.blinkReminderInterval, in: 30...1800, step: 30)
                        .onChange(of: reminderManager.blinkReminderInterval) { _ in
                            reminderManager.startTimers()
                        }
                }
                
                VStack(alignment: .leading) {
                    Text("20/20/20 Reminder: \(Int(reminderManager.countdownReminderInterval/60)) minutes")
                    Slider(value: $reminderManager.countdownReminderInterval, in: 60...3600, step: 60)
                        .onChange(of: reminderManager.countdownReminderInterval) { _ in
                            reminderManager.startTimers()
                        }
                }
            }
            .padding(.horizontal)
            
            Spacer()
            
            HStack {
                Spacer()
                Button("Close") {
                    NSApp.keyWindow?.close()
                }
                .keyboardShortcut(.escape, modifiers: [])
            }
            .padding(.horizontal)
        }
        .padding()
        .frame(minWidth: 350, minHeight: 500)
    }
}

// Preview
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
