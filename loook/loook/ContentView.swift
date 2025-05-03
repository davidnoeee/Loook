import SwiftUI
import ServiceManagement

struct ContentView: View {
    @StateObject private var reminderManager = ReminderManager()
    @State private var showSettings = false
    
    var body: some View {
        // Invisible view - no background elements, just the reminders as needed
        ZStack {
            Color.clear
                .frame(width: 0, height: 0)
                .contentShape(Rectangle()) // Just for hit-testing

            if reminderManager.showArrowReminder {
                VStack {
                    PostureReminderView(isShowing: $reminderManager.showArrowReminder)
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .offset(y: -20)),
                            removal: .opacity.combined(with: .offset(y: -40))
                        ))
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                    
                    Spacer()
                }
            }
            
            if reminderManager.showEyeReminder {
                VStack {
                    BlinkReminderView(isShowing: $reminderManager.showEyeReminder)
                        .transition(.scale.combined(with: .opacity))
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                    
                    Spacer()
                }
            }
            
            if reminderManager.showCountdownReminder {
                VStack {
                    CountdownReminderView(
                        isShowing: $reminderManager.showCountdownReminder,
                        secondsRemaining: $reminderManager.countdownSeconds
                    )
                    .transition(.opacity)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 40)
                    
                    Spacer()
                }
            }
        }
        .ignoresSafeArea()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear)
        .onAppear {
            reminderManager.startTimers()
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
        if launchAtLogin {
            try? SMAppService.mainApp.register()
        } else {
            try? SMAppService.mainApp.unregister()
        }
    }
    
    // Test methods
    func testPostureReminder() {
        // Hide other reminders first
        showEyeReminder = false
        showCountdownReminder = false
        
        // Show arrow reminder
        showArrowReminder = true
        
        // Auto-dismiss after 3 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            withAnimation {
                self.showArrowReminder = false
            }
        }
    }
    
    func testBlinkReminder() {
        // Hide other reminders first
        showArrowReminder = false
        showCountdownReminder = false
        
        // Show eye reminder
        showEyeReminder = true
        
        // Auto-dismiss after 2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                self.showEyeReminder = false
            }
        }
    }
    
    func testCountdownReminder() {
        // Hide other reminders first
        showArrowReminder = false
        showEyeReminder = false
        
        // Reset and show countdown
        countdownSeconds = 20
        showCountdownReminder = true
        
        // Start the countdown timer
        countdownProgressTimer?.invalidate()
        countdownProgressTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] timer in
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
            withAnimation(.spring(response: 0.6, dampingFraction: 0.6)) {
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
    @Binding var isPresented: Bool
    
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
                
                Divider()
                
                // Test buttons section
                Text("Test Animations")
                    .font(.headline)
                    .padding(.top, 5)
                
                HStack(spacing: 10) {
                    Button("Test Posture") {
                        reminderManager.testPostureReminder()
                    }
                    .buttonStyle(.bordered)
                    
                    Button("Test Blink") {
                        reminderManager.testBlinkReminder()
                    }
                    .buttonStyle(.bordered)
                    
                    Button("Test 20/20/20") {
                        reminderManager.testCountdownReminder()
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.top, 5)
            }
            .padding(.horizontal)
            
            Spacer(minLength: 10)
            
            HStack {
                Spacer()
                Button("Close") {
                    isPresented = false
                }
                .keyboardShortcut(.escape, modifiers: [])
            }
            .padding(.horizontal)
        }
        .padding()
        .frame(width: 350)
        .fixedSize(horizontal: true, vertical: true) // Makes the view hug its content vertically
    }
}
