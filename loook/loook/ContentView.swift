import SwiftUI
import ServiceManagement

struct ContentView: View {
    @ObservedObject var reminderManager: ReminderManager
    
    var body: some View {
        ZStack {
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
                .animation(.easeInOut, value: reminderManager.showArrowReminder)
            }
            
            if reminderManager.showEyeReminder {
                VStack {
                    BlinkReminderView(isShowing: $reminderManager.showEyeReminder)
                        .transition(.scale.combined(with: .opacity))
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                    
                    Spacer()
                }
                .animation(.easeInOut, value: reminderManager.showEyeReminder)
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
                .animation(.easeInOut, value: reminderManager.showCountdownReminder)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear)
        .onAppear {
            reminderManager.startTimers()
        }
    }
    
    init(reminderManager: ReminderManager = ReminderManager()) {
        self.reminderManager = reminderManager
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
        withAnimation {
            showEyeReminder = false
            showCountdownReminder = false
        }
        
        // Show arrow reminder
        DispatchQueue.main.async {
            withAnimation {
                self.showArrowReminder = true
            }
            
            // Auto-dismiss after 3 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                withAnimation {
                    self.showArrowReminder = false
                }
            }
        }
    }
    
    func testBlinkReminder() {
        // Hide other reminders first
        withAnimation {
            showArrowReminder = false
            showCountdownReminder = false
        }
        
        // Show eye reminder
        DispatchQueue.main.async {
            withAnimation {
                self.showEyeReminder = true
            }
            
            // Auto-dismiss after 2 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                withAnimation {
                    self.showEyeReminder = false
                }
            }
        }
    }
    
    func testCountdownReminder() {
        // Hide other reminders first
        withAnimation {
            showArrowReminder = false
            showEyeReminder = false
        }
        
        // Reset and show countdown
        countdownSeconds = 20
        
        DispatchQueue.main.async {
            withAnimation {
                self.showCountdownReminder = true
            }
            
            // Start the countdown timer
            self.countdownProgressTimer?.invalidate()
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
            // Header
            Text("Settings")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 10)
            
            // Settings content
            VStack(alignment: .leading, spacing: 18) {
                // Toggle section
                LuminareCard {
                    VStack(alignment: .leading, spacing: 12) {
                        LuminareToggle(title: "Enable Reminders", isOn: $reminderManager.isRemindersEnabled)
                            .onChange(of: reminderManager.isRemindersEnabled) { _ in
                                reminderManager.startTimers()
                            }
                        
                        LuminareToggle(title: "Launch at Login", isOn: $reminderManager.launchAtLogin)
                            .onChange(of: reminderManager.launchAtLogin) { _ in
                                reminderManager.toggleLaunchAtLogin()
                            }
                    }
                }
                
                // Sliders section
                LuminareCard {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Reminder Intervals")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.secondary)
                        
                        LuminareSlider(
                            title: "Posture Reminder",
                            value: $reminderManager.postureReminderInterval,
                            range: 60...3600,
                            step: 60,
                            formatter: { "\(Int($0/60)) min" }
                        )
                        .onChange(of: reminderManager.postureReminderInterval) { _ in
                            reminderManager.startTimers()
                        }
                        
                        LuminareSlider(
                            title: "Blink Reminder",
                            value: $reminderManager.blinkReminderInterval,
                            range: 30...1800,
                            step: 30,
                            formatter: { "\(Int($0/60)) min" }
                        )
                        .onChange(of: reminderManager.blinkReminderInterval) { _ in
                            reminderManager.startTimers()
                        }
                        
                        LuminareSlider(
                            title: "20/20/20 Reminder",
                            value: $reminderManager.countdownReminderInterval,
                            range: 60...3600,
                            step: 60,
                            formatter: { "\(Int($0/60)) min" }
                        )
                        .onChange(of: reminderManager.countdownReminderInterval) { _ in
                            reminderManager.startTimers()
                        }
                    }
                }
                
                // Test buttons section
                LuminareCard {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Preview Animations")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.secondary)
                        
                        HStack(spacing: 8) {
                            LuminareButton(title: "Posture", iconName: "arrow.up.circle") {
                                reminderManager.testPostureReminder()
                            }
                            
                            LuminareButton(title: "Blink", iconName: "eye") {
                                reminderManager.testBlinkReminder()
                            }
                            
                            LuminareButton(title: "20/20/20", iconName: "timer") {
                                reminderManager.testCountdownReminder()
                            }
                        }
                    }
                }
            }
            .padding(.horizontal)
            
            Spacer(minLength: 10)
            
            // Footer
            HStack {
                Spacer()
                LuminareButton(title: "Close", iconName: "xmark.circle") {
                    isPresented = false
                }
                .keyboardShortcut(.escape, modifiers: [])
            }
            .padding(.horizontal)
            .padding(.bottom, 10)
        }
        .frame(width: 350)
        .fixedSize(horizontal: true, vertical: true) // Makes the view hug its content vertically
    }
}

// Luminare Design System Components
struct LuminareCard<Content: View>: View {
    var content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content
                .padding(.vertical, 14)
                .padding(.horizontal, 16)
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .opacity(0.8)
        )
        .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 2)
    }
}

struct LuminareToggle: View {
    let title: String
    @Binding var isOn: Bool
    
    var body: some View {
        Toggle(isOn: $isOn) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.primary)
        }
        .toggleStyle(SwitchToggleStyle(tint: Color.accentColor))
    }
}

struct LuminareSlider: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let formatter: (Double) -> String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text(formatter(value))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
            }
            
            Slider(value: $value, in: range, step: step)
                .accentColor(.accentColor)
        }
    }
}

struct LuminareButton: View {
    let title: String
    let iconName: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: iconName)
                    .font(.system(size: 12))
                Text(title)
                    .font(.system(size: 13, weight: .medium))
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(LuminareButtonStyle())
    }
}

struct LuminareButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(configuration.isPressed ? .primary.opacity(0.7) : .primary)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(.ultraThinMaterial)
                    .opacity(configuration.isPressed ? 0.7 : 1)
            )
            .shadow(color: Color.black.opacity(configuration.isPressed ? 0.01 : 0.05),
                   radius: configuration.isPressed ? 2 : 4)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}
