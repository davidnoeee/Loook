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
                            insertion: .opacity.combined(with: .offset(y: -10)),
                            removal: .opacity.combined(with: .offset(y: -20))
                        ))
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                        .scaleEffect(0.75) // 25% smaller
                    
                    Spacer()
                }
                .animation(.spring(response: 0.5, dampingFraction: 0.7), value: reminderManager.showArrowReminder)
            }
            
            if reminderManager.showEyeReminder {
                VStack {
                    BlinkReminderView(isShowing: $reminderManager.showEyeReminder)
                        .transition(.scale.combined(with: .opacity))
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                        .scaleEffect(0.75) // 25% smaller
                    
                    Spacer()
                }
                .animation(.spring(response: 0.5, dampingFraction: 0.7), value: reminderManager.showEyeReminder)
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
                    .scaleEffect(0.75) // 25% smaller
                    
                    Spacer()
                }
                .animation(.spring(response: 0.5, dampingFraction: 0.7), value: reminderManager.showCountdownReminder)
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
    
    // Updated ranges with new step values
    @Published var postureReminderInterval: TimeInterval = 10 * 60 // 10 minutes
    @Published var blinkReminderInterval: TimeInterval = 60 // 1 minute
    @Published var distanceFocusReminderInterval: TimeInterval = 20 * 60 // 20 minutes
    
    @Published var isRemindersEnabled = true
    @AppStorage("launchAtLogin") var launchAtLogin = false
    
    private var postureTimer: Timer?
    private var blinkTimer: Timer?
    private var distanceFocusTimer: Timer?
    private var countdownProgressTimer: Timer?
    
    // Queue system for reminders
    private var reminderQueue: [ReminderType] = []
    private enum ReminderType { case posture, blink, distanceFocus }
    private var isShowingReminder: Bool = false
    
    func startTimers() {
        stopAllTimers()
        
        if isRemindersEnabled {
            // Posture reminder timer
            postureTimer = Timer.scheduledTimer(withTimeInterval: postureReminderInterval, repeats: true) { [weak self] _ in
                guard let self = self else { return }
                self.queueReminder(.posture)
            }
            
            // Blink reminder timer
            blinkTimer = Timer.scheduledTimer(withTimeInterval: blinkReminderInterval, repeats: true) { [weak self] _ in
                guard let self = self else { return }
                self.queueReminder(.blink)
            }
            
            // Distance Focus reminder timer (formerly 20/20/20 rule)
            distanceFocusTimer = Timer.scheduledTimer(withTimeInterval: distanceFocusReminderInterval, repeats: true) { [weak self] _ in
                guard let self = self else { return }
                self.queueReminder(.distanceFocus)
            }
        }
    }
    
    private func queueReminder(_ type: ReminderType) {
        // If countdown is showing, don't queue anything else
        if showCountdownReminder {
            return
        }
        
        // If already showing a reminder, add to queue unless it's already there
        if isShowingReminder {
            if !reminderQueue.contains(type) {
                reminderQueue.append(type)
            }
            return
        }
        
        // Otherwise, show the reminder immediately
        showReminder(type)
    }
    
    private func showReminder(_ type: ReminderType) {
        isShowingReminder = true
        
        // Clear all existing reminders first
        withAnimation {
            showArrowReminder = false
            showEyeReminder = false
            showCountdownReminder = false
        }
        
        // Wait a brief moment to ensure animations finish
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation {
                switch type {
                case .posture:
                    self.showArrowReminder = true
                    
                    // Auto-dismiss after 3 seconds
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        withAnimation {
                            self.showArrowReminder = false
                            self.checkQueue()
                        }
                    }
                    
                case .blink:
                    self.showEyeReminder = true
                    
                    // Auto-dismiss after 2 seconds
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        withAnimation {
                            self.showEyeReminder = false
                            self.checkQueue()
                        }
                    }
                    
                case .distanceFocus:
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
                                self.checkQueue()
                            }
                        }
                    }
                }
            }
        }
    }
    
    func checkQueue() {
        isShowingReminder = false
        
        // If there are items in the queue, show the next one
        if !reminderQueue.isEmpty {
            let nextReminder = reminderQueue.removeFirst()
            showReminder(nextReminder)
        }
    }
    
    func resetPopups() {
        // Clear all reminders and the queue
        withAnimation {
            showArrowReminder = false
            showEyeReminder = false
            showCountdownReminder = false
            isShowingReminder = false
            reminderQueue.removeAll()
            countdownProgressTimer?.invalidate()
        }
    }
    
    func stopAllTimers() {
        postureTimer?.invalidate()
        blinkTimer?.invalidate()
        distanceFocusTimer?.invalidate()
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
        queueReminder(.posture)
    }
    
    func testBlinkReminder() {
        queueReminder(.blink)
    }
    
    func testDistanceFocusReminder() {
        queueReminder(.distanceFocus)
    }
}

// Posture Reminder View (Arrow in Pill)
struct PostureReminderView: View {
    @Binding var isShowing: Bool
    @State private var circleOffset: CGFloat = 40
    @State private var frameOpacity: Double = 0
    @State private var circleOpacity: Double = 0
    @State private var arrowBounce: CGFloat = 0
    
    var body: some View {
        ZStack {
            // Pill background
            Capsule()
                .fill(Material.ultraThinMaterial)
                .frame(width: 100, height: 140)
                .overlay(
                    Capsule()
                        .strokeBorder(LinearGradient(
                            colors: [.white.opacity(0.2), .white.opacity(0.05)],
                            startPoint: .top,
                            endPoint: .bottom
                        ), lineWidth: 0.5)
                )
                .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
                .opacity(frameOpacity)
            
            // Circle with arrow
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.white, .white.opacity(0.9)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 70, height: 70)
                    .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                
                Image(systemName: "arrow.up")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.black)
                    .offset(y: arrowBounce)
            }
            .offset(y: circleOffset)
            .opacity(circleOpacity)
        }
        .onAppear {
            // Initial state
            circleOffset = 20
            frameOpacity = 0
            circleOpacity = 0
            
            // First fade in the frame quickly
            withAnimation(.easeIn(duration: 0.2)) {
                frameOpacity = 1
            }
            
            // Then fade in the circle at bottom position
            withAnimation(.easeIn(duration: 0.3).delay(0.1)) {
                circleOpacity = 1
            }
            
            // Move circle up with a bounce
            withAnimation(.spring(response: 0.8, dampingFraction: 0.65).delay(0.4)) {
                circleOffset = -20 // Consistent padding at top
            }
            
            // Add a subtle bounce to the arrow
            withAnimation(.spring(response: 0.5, dampingFraction: 0.5).delay(0.6).repeatCount(1, autoreverses: true)) {
                arrowBounce = -5
            }
            
            // Fade out the circle first
            withAnimation(.easeOut(duration: 0.3).delay(2.3)) {
                circleOpacity = 0
            }
            
            // Then quickly fade out the frame
            withAnimation(.easeOut(duration: 0.2).delay(2.5)) {
                frameOpacity = 0
            }
        }
    }
}

// Blink Reminder View (Eye in Circle)
struct BlinkReminderView: View {
    @Binding var isShowing: Bool
    @State private var scale: CGFloat = 0.5
    @State private var frameOpacity: Double = 0
    @State private var circleOpacity: Double = 0
    @State private var eyeBounce: CGFloat = 0
    
    var body: some View {
        ZStack {
            // Circle background
            Circle()
                .fill(Material.ultraThinMaterial)
                .frame(width: 100, height: 100)
                .overlay(
                    Circle()
                        .strokeBorder(LinearGradient(
                            colors: [.white.opacity(0.2), .white.opacity(0.05)],
                            startPoint: .top,
                            endPoint: .bottom
                        ), lineWidth: 0.5)
                )
                .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
                .opacity(frameOpacity)
            
            // Circle with eye
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.white, .white.opacity(0.9)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 70, height: 70)
                    .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                    .scaleEffect(scale)
                
                Image(systemName: "eye")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.black)
                    .scaleEffect(scale)
                    .offset(y: eyeBounce)
            }
            .opacity(circleOpacity)
        }
        .onAppear {
            // Initial state
            scale = 0.5
            frameOpacity = 0
            circleOpacity = 0
            
            // First fade in the frame quickly
            withAnimation(.easeIn(duration: 0.2)) {
                frameOpacity = 1
            }
            
            // Then fade in and scale the circle
            withAnimation(.spring(response: 0.6, dampingFraction: 0.65).delay(0.1)) {
                scale = 1.0
                circleOpacity = 1.0
            }
            
            // Add a subtle bounce to the eye icon
            withAnimation(.spring(response: 0.4, dampingFraction: 0.5).delay(0.4)) {
                eyeBounce = -5
            }
            
            withAnimation(.spring(response: 0.4, dampingFraction: 0.5).delay(0.9)) {
                eyeBounce = 0
            }
            
            // Fade out the circle first
            withAnimation(.easeOut(duration: 0.3).delay(1.4)) {
                scale = 0.6
                circleOpacity = 0
            }
            
            // Then quickly fade out the frame
            withAnimation(.easeOut(duration: 0.2).delay(1.6)) {
                scale = 0.6
                frameOpacity = 0
            }
        }
    }
}

// Countdown Reminder View (Distance Focus)
struct CountdownReminderView: View {
    @Binding var isShowing: Bool
    @Binding var secondsRemaining: Int
    @State private var isHovering = false
    @State private var scale: CGFloat = 0.9
    
    var body: some View {
        ZStack {
            // Horizontal pill
            Capsule()
                .fill(Material.ultraThinMaterial)
                .frame(width: 140, height: 60)
                .overlay(
                    Capsule()
                        .strokeBorder(LinearGradient(
                            colors: [.white.opacity(0.2), .white.opacity(0.05)],
                            startPoint: .top,
                            endPoint: .bottom
                        ), lineWidth: 0.5)
                )
                .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
            
            // Content with countdown and dismiss button
            HStack(spacing: 8) {
                // Countdown text
                Text("\(secondsRemaining)s")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(.primary)
                    .contentTransition(.numericText())
                    .animation(.spring(response: 0.35, dampingFraction: 0.8), value: secondsRemaining)
                
                // Dismiss button (only visible on hover)
                if isHovering {
                    Button {
                        withAnimation {
                            isShowing = false
                            // Also notify the reminder manager that this reminder has completed
                            DispatchQueue.main.async {
                                NotificationCenter.default.post(name: NSNotification.Name("CountdownDismissed"), object: nil)
                            }
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .transition(.opacity)
                }
            }
            .padding(.horizontal, isHovering ? 8 : 0)
        }
        .scaleEffect(scale)
        .onAppear {
            // Start slightly smaller
            scale = 0.9
            
            // Bounce in animation
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                scale = 1.0
            }
            
            // Add observer for dismissal notification
            NotificationCenter.default.addObserver(forName: NSNotification.Name("CountdownDismissed"), object: nil, queue: .main) { _ in
                DispatchQueue.main.async {
                    withAnimation {
                        self.isShowing = false
                    }
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

// Settings View with refined Luminare Design
struct SettingsView: View {
    @ObservedObject var reminderManager: ReminderManager
    @Binding var isPresented: Bool
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Header
                Text("Settings")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 8)
                
                // Settings content
                VStack(alignment: .leading, spacing: 14) {
                    // Toggle section
                    LuminareCard {
                        VStack(alignment: .leading, spacing: 12) {
                            LuminareToggle(title: "Enable Reminders", isOn: $reminderManager.isRemindersEnabled)
                                .onChange(of: reminderManager.isRemindersEnabled) { _ in
                                    reminderManager.startTimers()
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            LuminareToggle(title: "Launch at Login", isOn: $reminderManager.launchAtLogin)
                                .onChange(of: reminderManager.launchAtLogin) { _ in
                                    reminderManager.toggleLaunchAtLogin()
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    
                    // Sliders section
                    LuminareCard {
                        VStack(alignment: .leading, spacing: 18) {
                            Text("Reminder Intervals")
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                                .foregroundColor(.secondary)
                            
                            // Posture reminder: 5-30 minutes in 5-minute steps
                            LuminareSlider(
                                title: "Posture Reminder",
                                value: $reminderManager.postureReminderInterval,
                                range: 300...1800, // 5-30 minutes
                                step: 300, // 5 minute steps
                                formatter: { "\(Int($0/60)) min" }
                            )
                            .onChange(of: reminderManager.postureReminderInterval) { _ in
                                reminderManager.startTimers()
                            }
                            
                            // Blink reminder: 15sec-10min with variable steps
                            LuminareSlider(
                                title: "Blink Reminder",
                                value: $reminderManager.blinkReminderInterval,
                                range: 15...600, // 15sec-10min
                                step: reminderManager.blinkReminderInterval < 60 ? 15 : 60, // 15sec steps until 1min, then 1min steps
                                formatter: {
                                    let value = Int($0)
                                    return value < 60 ? "\(value)s" : "\(value/60) min"
                                }
                            )
                            .onChange(of: reminderManager.blinkReminderInterval) { _ in
                                reminderManager.startTimers()
                            }
                            
                            // Distance Focus reminder: 5-30 minutes in 5-minute steps
                            LuminareSlider(
                                title: "Distance Focus",
                                value: $reminderManager.distanceFocusReminderInterval,
                                range: 300...1800, // 5-30 minutes
                                step: 300, // 5 minute steps
                                formatter: { "\(Int($0/60)) min" }
                            )
                            .onChange(of: reminderManager.distanceFocusReminderInterval) { _ in
                                reminderManager.startTimers()
                            }
                        }
                    }
                    
                    // Test buttons section
                    LuminareCard {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Preview Animations")
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                                .foregroundColor(.secondary)
                            
                            VStack(spacing: 8) {
                                LuminareButton(title: "Posture", iconName: "arrow.up.circle") {
                                    reminderManager.testPostureReminder()
                                }
                                
                                LuminareButton(title: "Blink", iconName: "eye") {
                                    reminderManager.testBlinkReminder()
                                }
                                
                                LuminareButton(title: "Distance Focus", iconName: "ruler") {
                                    reminderManager.testDistanceFocusReminder()
                                }
                            }
                        }
                    }
                    
                    // Reset & Quit section
                    LuminareCard {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("App Controls")
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                                .foregroundColor(.secondary)
                            
                            VStack(spacing: 8) {
                                LuminareButton(title: "Reset Pop-ups", iconName: "arrow.clockwise") {
                                    reminderManager.resetPopups()
                                }
                                
                                LuminareButton(title: "Close", iconName: "xmark.circle") {
                                    isPresented = false
                                }
                                
                                LuminareButton(title: "Quit App", iconName: "power", style: .destructive) {
                                    NSApplication.shared.terminate(nil)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 12)
            }
            .padding(.vertical, 8)
        }
        .frame(width: 320)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Material.ultraThinMaterial)
        )
    }
}

// Enhanced Luminare Design System Components
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
            RoundedRectangle(cornerRadius: 14)
                .fill(Material.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(LinearGradient(
                    colors: [.white.opacity(0.2), .white.opacity(0.05)],
                    startPoint: .top,
                    endPoint: .bottom
                ), lineWidth: 0.5)
        )
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
}

struct LuminareToggle: View {
    let title: String
    @Binding var isOn: Bool
    
    var body: some View {
        Toggle(isOn: $isOn) {
            Text(title)
                .font(.system(size: 14, weight: .medium, design: .rounded))
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
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text(formatter(value))
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
                    .frame(minWidth: 45, alignment: .trailing)
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
    let style: ButtonStyle
    
    enum ButtonStyle {
        case standard, destructive
    }
    
    init(title: String, iconName: String, style: ButtonStyle = .standard, action: @escaping () -> Void) {
        self.title = title
        self.iconName = iconName
        self.style = style
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: iconName)
                    .font(.system(size: 12))
                Text(title)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
            }
            .padding(.vertical, 7)
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(LuminareButtonStyle(style: style))
    }
}

struct LuminareButtonStyle: ButtonStyle {
    let style: LuminareButton.ButtonStyle
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(foregroundColor(configuration))
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Material.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(strokeColor(configuration), lineWidth: 0.5)
                    )
            )
            .shadow(color: Color.black.opacity(configuration.isPressed ? 0.01 : 0.03),
                   radius: configuration.isPressed ? 1 : 3)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: configuration.isPressed)
    }
    
    func foregroundColor(_ configuration: Configuration) -> Color {
        switch style {
        case .standard:
            return configuration.isPressed ? .primary.opacity(0.7) : .primary
        case .destructive:
            return configuration.isPressed ? .red.opacity(0.7) : .red
        }
    }
    
    func strokeColor(_ configuration: Configuration) -> Color {
        switch style {
        case .standard:
            return .white.opacity(configuration.isPressed ? 0.05 : 0.1)
        case .destructive:
            return .red.opacity(configuration.isPressed ? 0.1 : 0.2)
        }
    }
}
