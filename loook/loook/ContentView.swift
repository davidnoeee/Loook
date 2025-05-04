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
    
    @Published var isBlinkReminderEnabled: Bool = true
    @Published var isPostureReminderEnabled: Bool = true
    @Published var isDistanceFocusReminderEnabled: Bool = true
    
    @Published var isRemindersEnabled = true
    @AppStorage("launchAtLogin") var launchAtLogin = false
    
    private var postureTimer: Timer?
    private var blinkTimer: Timer?
    private var distanceFocusTimer: Timer?
    private var countdownProgressTimer: Timer?
    
    // Queue system for reminders
    private var reminderQueue: [ReminderType] = []
    private enum ReminderType { case posture, blink, distanceFocus }
    var isShowingReminder: Bool = false
    
    func startTimers() {
        stopAllTimers()
        
        if isRemindersEnabled {
            // Posture reminder timer - only if enabled
            if isPostureReminderEnabled {
                postureTimer = Timer.scheduledTimer(withTimeInterval: postureReminderInterval, repeats: true) { [weak self] _ in
                    guard let self = self else { return }
                    self.queueReminder(.posture)
                }
            }
            
            // Blink reminder timer - only if enabled
            if isBlinkReminderEnabled {
                blinkTimer = Timer.scheduledTimer(withTimeInterval: blinkReminderInterval, repeats: true) { [weak self] _ in
                    guard let self = self else { return }
                    self.queueReminder(.blink)
                }
            }
            
            // Distance Focus reminder timer - only if enabled
            if isDistanceFocusReminderEnabled {
                distanceFocusTimer = Timer.scheduledTimer(withTimeInterval: distanceFocusReminderInterval, repeats: true) { [weak self] _ in
                    guard let self = self else { return }
                    self.queueReminder(.distanceFocus)
                }
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
                    DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                        withAnimation {
                            self.showArrowReminder = false
                            self.checkQueue()
                        }
                    }
                    
                case .blink:
                    self.showEyeReminder = true
                    
                    // Auto-dismiss after 2 seconds
                    DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
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
                            // Don't immediately hide - let the view handle it with its own animations
                            // The view will set isShowing = false when animations complete
                            
                            // Check queue after a reasonable delay to allow animations to complete
                            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
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

// Updated Posture Reminder View with new design language
struct PostureReminderView: View {
    @Binding var isShowing: Bool
    
    // Frame animation states
    @State private var frameScale: CGFloat = 0.2
    @State private var frameOpacity: Double = 0
    @State private var frameBlur: CGFloat = 25
    @State private var frameHeight: CGFloat = 120
    @State private var frameWidth: CGFloat = 100
    @State private var frameOffsetY: CGFloat = 20
    
    // Circle animation states
    @State private var circleScale: CGFloat = 0.2
    @State private var circleOpacity: Double = 0
    @State private var circleOffset: CGFloat = 20
    @State private var circleBlur: CGFloat = 15
    
    // Arrow animation states
    @State private var arrowScale: CGFloat = 0.2
    @State private var arrowOpacity: Double = 0
    @State private var arrowBounce: CGFloat = 0
    @State private var arrowBlur: CGFloat = 5
    
    // To prevent multiple exit animations
    @State private var isAnimatingOut: Bool = false
    
    var body: some View {
        ZStack {
            // Pill background that can morph to circle
            Capsule(style: .continuous)
                .fill(Material.ultraThinMaterial)
                .frame(width: frameWidth, height: frameHeight)
                .overlay {
                    Capsule(style: .continuous)
                        .stroke(Color.black, lineWidth: 0.8)
                }
                .overlay {
                    Capsule(style: .continuous)
                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                        .padding(0.8)
                }
                .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 3)
                .shadow(color: .black.opacity(0.35), radius: 20, x: 0, y: 5)
                .scaleEffect(frameScale)
                .opacity(frameOpacity)
                .blur(radius: frameBlur)
                .offset(y: frameOffsetY)
            
            // Circle with arrow - playful bouncy movement
            ZStack {
                // White circle
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.white, .white.opacity(0.9)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 70, height: 70)
                    .overlay {
                        Circle()
                            .stroke(Color.black.opacity(0.15), lineWidth: 0.5)
                    }
                    .overlay {
                        Circle()
                            .stroke(Color.white.opacity(0.5), lineWidth: 0.5)
                            .padding(0.5)
                    }
                    .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                    .scaleEffect(circleScale)
                    .blur(radius: circleBlur)
                    .opacity(circleOpacity)
                
                // Arrow with bouncy animation
                Image(systemName: "arrow.up")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.black)
                    .offset(y: arrowBounce)
                    .scaleEffect(arrowScale)
                    .opacity(arrowOpacity)
                    .blur(radius: arrowBlur)
            }
            .offset(y: circleOffset)
        }
        .environment(\.colorScheme, .dark)
        .onAppear(perform: startAnimation)
        .onChange(of: isShowing) { newValue in
            if !newValue && !isAnimatingOut {
                startExitAnimation()
            }
        }
    }
    
    private func startAnimation() {
        // PLAYFUL YET FLUID ANIMATION SEQUENCE
        
        // 1. Frame appears with bounce and blur
        withAnimation(.spring(response: 0.45, dampingFraction: 0.65)) {
            frameScale = 1.07
            frameOpacity = 1
            frameBlur = 5
            circleBlur = 5
            arrowBlur = 0
        }
        
        // Frame settles with less blur
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                frameScale = 1.0
                frameBlur = 0
                circleBlur = 0
            }
        }
        
        // 2. Circle appears quickly after frame starts appearing
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.65)) {
                circleScale = 1.08
                circleOpacity = 1
                frameHeight = 140
                frameOffsetY = 0
            }
            
            // Circle settles to normal size
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    circleScale = 1.0
                }
            }
            
            // Circle moves upwards with playful bounce
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                withAnimation(.spring(response: 0.7, dampingFraction: 0.65)) {
                    circleOffset = -20
                }
            }
        }
        
        // 3. Arrow appears and does a playful bounce
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                arrowScale = 1.0
                arrowOpacity = 1
            }
            
            // First playful bounce - up
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.55)) {
                    arrowBounce = -11 // Bigger bounce for playfulness
                    frameOffsetY = -3.5
                    frameWidth = 98
                    circleOffset = -24
                }
                
                // Bounce back
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.65)) {
                        arrowBounce = -2 // Slight overshoot
                        frameOffsetY = 0
                        frameWidth = 100
                        circleOffset = -20
                    }
                    
                    // Small final adjustment
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            arrowBounce = -3 // Settle to slightly raised position
                        }
                    }
                }
            }
        }
        
        // 4. Automatic exit animation after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            startExitAnimation()
        }
    }
    
    private func startExitAnimation() {
        // Prevent multiple exit animations
        if isAnimatingOut {
            return
        }
        isAnimatingOut = true
        
        // CONSISTENT EXIT ANIMATION PATTERN
        
        // 1. First a slight "prepare to exit" animation
        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
            frameScale = 1.05
            circleScale = 1.05
            arrowScale = 1.05
            frameBlur = 2
        }
        
        // 2. Content elements exit first
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            // First hide the arrow
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                arrowScale = 0.6
                arrowOpacity = 0
                arrowBlur = 5
            }
            
            // Then start circle exit
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.7)) {
                    circleScale = 0.7
                    circleOpacity = 0
                    circleBlur = 8
                    frameHeight = 90 // Start morphing pill back to smaller
                    frameOffsetY = 10
                    circleOffset = 20
                }
                
                // 3. Finally the frame disappears
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    // First frame changes with bounce
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                        frameScale = 0.8
                        frameBlur = 10
                    }
                    
                    // Then final fade out
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation(.easeOut(duration: 0.2)) {
                            frameOpacity = 0
                            frameBlur = 20
                        }
                        
                        // Notify after animations complete
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            isShowing = false
                        }
                    }
                }
            }
        }
    }
}
// Enhanced Blink Reminder View with playful animations
// Enhanced Blink Reminder View with playful animations
struct BlinkReminderView: View {
    @Binding var isShowing: Bool
    
    // Frame animation states
    @State private var frameScale: CGFloat = 0.2
    @State private var frameOpacity: Double = 0
    @State private var frameBlur: CGFloat = 15
    
    // Circle animation states
    @State private var circleScale: CGFloat = 0.2
    @State private var circleOpacity: Double = 0
    @State private var circleBlur: CGFloat = 10
    @State private var circleOffset: CGFloat = 0
    
    @State private var circleColor: Color = .white.opacity(1)
    
    // Eye animation states
    @State private var eyeScale: CGFloat = 0.2
    @State private var eyeOpacity: Double = 0
    @State private var eyeBlur: CGFloat = 5
    @State private var eyeBounce: CGFloat = 0
    
    @State private var eyeColor: Color = .black.opacity(1)
    
    // To prevent multiple exit animations
    @State private var isAnimatingOut: Bool = false
    
    var body: some View {
        ZStack {
            // Circle background with new design
            Circle()
                .fill(Material.ultraThinMaterial)
                .frame(width: 100, height: 100)
                .overlay {
                    Circle()
                        .stroke(Color.black, lineWidth: 0.8)
                }
                .overlay {
                    Circle()
                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                        .padding(0.8)
                }
                .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 3)
                .shadow(color: .black.opacity(0.35), radius: 20, x: 0, y: 5)
                .scaleEffect(frameScale)
                .opacity(frameOpacity)
                .blur(radius: frameBlur)
            
            // White circle with eye icon
            ZStack {
                Circle()
                    .fill(circleColor)
                    .frame(width: 70, height: 70)
                    .overlay {
                        Circle()
                            .stroke(Color.black.opacity(0.15), lineWidth: 0.5)
                    }
                    .overlay {
                        Circle()
                            .stroke(Color.white.opacity(0.5), lineWidth: 0.5)
                            .padding(0.5)
                    }
                    .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                    .scaleEffect(circleScale)
                    .blur(radius: circleBlur)
                    .opacity(circleOpacity)
                    .offset(y: circleOffset)
                
                // Eye icon with bounce animation
                Image(systemName: "eye")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(eyeColor)
                    .scaleEffect(eyeScale)
                    .opacity(eyeOpacity)
                    .blur(radius: eyeBlur)
                    .offset(y: eyeBounce)
            }
        }
        .environment(\.colorScheme, .dark)
        .onAppear(perform: startAnimation)
        .onChange(of: isShowing) { newValue in
            if !newValue && !isAnimatingOut {
                startExitAnimation()
            }
        }
    }
    
    private func startAnimation() {
        // PLAYFUL FLUID ANIMATION SEQUENCE
        
        // 1. Frame appears with bounce
        withAnimation(.spring(response: 0.45, dampingFraction: 0.65)) {
            frameScale = 1.12
            frameOpacity = 1
            frameBlur = 5
        }
        
        // Frame settles to normal size
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                frameScale = 1.0
                frameBlur = 0
            }
        }
        
        // 2. Circle appears with slight delay and bounce
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.65)) {
                circleScale = 1.15
                circleOpacity = 1
                circleBlur = 3
                circleOffset = -5 // Slight upward movement
            }
            
            // Circle settles
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    circleScale = 1.0
                    circleBlur = 0
                    circleOffset = 0
                }
            }
        }
        
        // 3. Eye appears with playful animations
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                eyeScale = 1.0
                eyeOpacity = 1
                eyeBlur = 0
            }
            
            // First playful bounce - eye "blinks"
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                // Open eye with bounce
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        eyeScale = 0.8 // Eye opens wider
                        circleScale = 1.08 // Circle reacts slightly
                        eyeColor = .white.opacity(0.8)
                        circleColor = .white.opacity(0.05)
                        eyeBlur = 1
                    }
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.9)) {
                            frameScale = 1.04 // Frame reacts slightly
                        }
                        
                        // Settle to normal
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                eyeScale = 1.0
                                circleScale = 1.0
                                eyeColor = .black
                                circleColor = .white
                                eyeBlur = 0
                            }
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.39) {
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.9)) {
                                frameScale = 1.0 // Frame reacts slightly
                            }
                        }
                        
                        // Exit animation after delay
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                            startExitAnimation()
                        }
                    }
                }
            }
        }
    }
    
    private func startExitAnimation() {
        // Prevent multiple exit animations
        if isAnimatingOut {
            return
        }
        isAnimatingOut = true
        
        // CONSISTENT EXIT ANIMATION PATTERN
        
        // 1. First prepare to exit - slight pulse
        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
            frameScale = 1.03
            circleScale = 1.09
            eyeScale = 1.05
            frameBlur = 1
        }
        
        // 2. Eye disappears first
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                eyeScale = 0.6
                eyeOpacity = 0
                eyeBlur = 5
            }
            
            // 3. Then inner circle animates out
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.7)) {
                    circleScale = 0.7
                    circleOpacity = 0
                    circleBlur = 8
                }
                
                // 4. Finally the frame disappears
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    // First scale down with blur
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                        frameScale = 0.8
                        frameBlur = 10
                    }
                    
                    // Then final fade out
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation(.easeOut(duration: 0.2)) {
                            frameOpacity = 0
                            frameBlur = 20
                        }
                        
                        // Set isShowing to false after animation completes
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            isShowing = false
                        }
                    }
                }
            }
        }
    }
}
// Enhanced Countdown Reminder View with fluid animations and completion transformation
struct CountdownReminderView: View {
    @Binding var isShowing: Bool
    @Binding var secondsRemaining: Int
    
    // Frame animation states
    @State private var frameWidth: CGFloat = 150
    @State private var frameHeight: CGFloat = 60
    @State private var frameOpacity: Double = 0
    @State private var frameBlur: CGFloat = 30
    @State private var frameScale: CGFloat = 0.5
    @State private var frameOffset: CGFloat = 0
    @State private var isHovering = false
    
    // Text animation states
    @State private var textOpacity: Double = 0
    @State private var textScale: CGFloat = 0.6
    @State private var textBlur: CGFloat = 15
    
    // Completion animation states
    @State private var isShowingCompletion: Bool = false
    @State private var innerCircleOpacity: Double = 0
    @State private var innerCircleScale: CGFloat = 0.2
    @State private var innerCircleBlur: CGFloat = 10
    @State private var checkmarkOpacity: Double = 0
    @State private var checkmarkScale: CGFloat = 0.2
    @State private var checkmarkBlur: CGFloat = 5
    
    // For tracking previous time to trigger animations
    @State private var previousSeconds: Int = 0
    @State private var isAnimatingOut: Bool = false
    
    var body: some View {
        ZStack {
            // Adaptable shape that morphs from pill to circle
            RoundedRectangle(cornerRadius: frameHeight / 2)
                .fill(Material.ultraThinMaterial)
                .frame(width: frameWidth, height: frameHeight)
                .overlay {
                    RoundedRectangle(cornerRadius: frameHeight / 2)
                        .stroke(Color.black, lineWidth: 0.8)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: frameHeight / 2)
                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                        .padding(0.8)
                }
                .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 3)
                .shadow(color: .black.opacity(0.35), radius: 20, x: 0, y: 5)
                .opacity(frameOpacity)
                .blur(radius: frameBlur)
                .scaleEffect(frameScale)
                .offset(y: frameOffset)
            
            if !isShowingCompletion {
                // Content with countdown and dismiss button
                HStack(spacing: 8) {
                    // Countdown text with fluid animations
                    Text("\(secondsRemaining)s")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundColor(.primary)
                        .contentTransition(.numericText(countsDown: true))
                        .opacity(textOpacity)
                        .scaleEffect(textScale)
                        .blur(radius: textBlur)
                        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: secondsRemaining)
                    
                    // Dismiss button (only visible on hover)
                    if isHovering {
                        Button {
                            startExitAnimation()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 16, design: .rounded))
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                        .transition(.opacity)
                    }
                }
                .padding(.horizontal, isHovering ? 8 : 0)
            } else {
                // Completion view with white circle and checkmark
                ZStack {
                    // White inner circle
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.white, .white.opacity(0.9)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 70, height: 70)
                        .overlay {
                            Circle()
                                .stroke(Color.black.opacity(0.15), lineWidth: 0.5)
                        }
                        .overlay {
                            Circle()
                                .stroke(Color.white.opacity(0.5), lineWidth: 0.5)
                                .padding(0.5)
                        }
                        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                        .scaleEffect(innerCircleScale)
                        .blur(radius: innerCircleBlur)
                        .opacity(innerCircleOpacity)
                    
                    // Checkmark icon
                    Image(systemName: "checkmark")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.black)
                        .scaleEffect(checkmarkScale)
                        .opacity(checkmarkOpacity)
                        .blur(radius: checkmarkBlur)
                }
            }
        }
        .environment(\.colorScheme, .dark)
        .onAppear {
            startEntranceAnimation()
            previousSeconds = secondsRemaining
        }
        .onChange(of: secondsRemaining) { newValue in
            if newValue != previousSeconds {
                animateWidthChange()
                previousSeconds = newValue
                
                // Transform to completion when countdown reaches zero
                if newValue == 0 && !isShowingCompletion && !isAnimatingOut {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        startCompletionTransformation()
                    }
                }
            }
        }
        .onChange(of: isShowing) { newValue in
            // If parent tries to hide this view while we're showing completion,
            // make sure our own animations finish properly
            if !newValue && !isAnimatingOut {
                if isShowingCompletion {
                    startExitAnimationAfterCompletion()
                } else {
                    startExitAnimation()
                }
            }
        }
        .onHover { hovering in
            if !isShowingCompletion {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isHovering = hovering
                }
            }
        }
    }
    
    // MARK: - Animation Functions
    
    private func startEntranceAnimation() {
        // Initial state
        frameOpacity = 0
        frameBlur = 20
        frameScale = 0.8
        textOpacity = 0
        textScale = 0.8
        textBlur = 10
        
        // 1. Animate in the frame with blur and scale
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
            frameOpacity = 1
            frameBlur = 0
            frameScale = 1.07 // Slight overshoot
        }
        
        // Frame settles
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                frameScale = 1.0
            }
        }
        
        // 2. Animate in the text with slight delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.65)) {
                textOpacity = 1
                textScale = 1.15 // Slight overshoot
                textBlur = 0
            }
            
            // Text settles
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                    textScale = 1.0
                }
            }
        }
    }
    
    private func animateWidthChange() {
        // Calculate new width based on remaining seconds (150 → 70 in steps of 4)
        let maxWidth: CGFloat = 150
        let minWidth: CGFloat = 70
        let totalSteps = 20 // Assuming 20 seconds countdown
        
        // Calculate width proportionally to remaining time
        let remainingSteps = CGFloat(secondsRemaining)
        let newWidth = max(minWidth, minWidth + (maxWidth - minWidth) * (remainingSteps / CGFloat(totalSteps)))
        
        // Animated width change with subtle bounce and blur
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            frameBlur = 1.2 // Very subtle blur during animation
            frameHeight = 58
            frameOffset = 1.5
        }
        
        withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) {
            frameWidth = newWidth
        }
        
        // Remove the subtle blur after animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            withAnimation(.easeOut(duration: 0.3)) {
                frameBlur = 0
                frameHeight = 60
                frameOffset = 0
            }
        }
    }
    
    private func startCompletionTransformation() {
        // 1. Fade out text content
        withAnimation(.spring(response: 0.4, dampingFraction: 0.65)) {
            textOpacity = 0
            textScale = 0.8
            textBlur = 5
        }
        
        // 2. Begin transformation from pill to circle
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.7)) {
                // Transform to circle
                frameWidth = 100
                frameHeight = 100
                frameScale = 1.05 // Slight overshoot
                frameBlur = 2 // Slight blur during transformation
            }
            
            // 3. Signal that we're now showing completion state
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                isShowingCompletion = true
                
                // Settle frame after transformation
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    frameScale = 1.0
                    frameBlur = 0
                }
                
                // 4. Animate in the inner white circle
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.65)) {
                        innerCircleOpacity = 1
                        innerCircleScale = 1.15 // Slight overshoot
                        innerCircleBlur = 0
                    }
                    
                    // Inner circle settles
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                            innerCircleScale = 1.0
                        }
                    }
                    
                    // 5. Animate in the checkmark with slight delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                        withAnimation(.spring(response: 0.45, dampingFraction: 0.65)) {
                            checkmarkOpacity = 1
                            checkmarkScale = 1.2 // Bigger overshoot for emphasis
                            checkmarkBlur = 0
                        }
                        
                        // Checkmark settles
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                                checkmarkScale = 1.0
                            }
                        }
                        
                        // 6. Wait for a moment then begin exit animation (no pulse animation)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                            startExitAnimationAfterCompletion()
                        }
                    }
                }
            }
        }
    }
    
    private func startExitAnimationAfterCompletion() {
        // Prevent multiple exit animations
        if isAnimatingOut {
            return
        }
        isAnimatingOut = true
        
        // CONSISTENT EXIT ANIMATION PATTERN
        
        // 1. First prepare for exit with slight scale up
        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
            frameScale = 1.03
            innerCircleScale = 1.05
            checkmarkScale = 1.03
            frameBlur = 1
        }
        
        // 2. First animate out the checkmark
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                checkmarkScale = 0.6
                checkmarkOpacity = 0
                checkmarkBlur = 5
            }
            
            // 3. Then animate out the inner circle with delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.7)) {
                    innerCircleScale = 0.7
                    innerCircleOpacity = 0
                    innerCircleBlur = 8
                }
                
                // 4. Finally, animate out the frame
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    // First scale down with blur
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                        frameScale = 0.8
                        frameBlur = 10
                    }
                    
                    // Then final fade out
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation(.easeOut(duration: 0.2)) {
                            frameOpacity = 0
                            frameBlur = 20
                        }
                        
                        // Notify after animations complete
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            isShowing = false
                            NotificationCenter.default.post(name: NSNotification.Name("CountdownDismissed"), object: nil)
                        }
                    }
                }
            }
        }
    }
    
    private func startExitAnimation() {
        // Prevent multiple exit animations
        if isAnimatingOut {
            return
        }
        isAnimatingOut = true
        
        // CONSISTENT EXIT ANIMATION PATTERN
        
        // 1. First make the text bounce out with blur
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            textScale = 1.1
            textOpacity = 0
            textBlur = 5
        }
        
        // 2. Then animate the frame
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            // First a little prep bounce
            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                frameScale = 1.05
                frameBlur = 2
            }
            
            // Then scale down with blur
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                    frameScale = 0.8
                    frameBlur = 10
                }
                
                // Final fade out as separate animation
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation(.easeOut(duration: 0.2)) {
                        frameOpacity = 0
                        frameBlur = 20
                    }
                }
                
                // Notify after animations complete
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    isShowing = false
                    NotificationCenter.default.post(name: NSNotification.Name("CountdownDismissed"), object: nil)
                }
            }
        }
    }
}

/*
struct SettingsView: View {
    @ObservedObject var reminderManager: ReminderManager
    @Binding var isPresented: Bool
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        VStack {
            Section {
                Toggle("Enable Reminders", isOn: $reminderManager.isRemindersEnabled)
                    .onChange(of: reminderManager.isRemindersEnabled) { _ in
                        reminderManager.startTimers()
                    }
                
                Toggle("Launch at Login", isOn: $reminderManager.launchAtLogin)
                    .onChange(of: reminderManager.launchAtLogin) { _ in
                        reminderManager.toggleLaunchAtLogin()
                    }
            } header: {
                Text("General")
            }
            
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Blink")
                        Spacer()
                        Text(reminderManager.blinkReminderInterval < 60 ?
                             "\(Int(reminderManager.blinkReminderInterval))s" :
                             "\(Int(reminderManager.blinkReminderInterval/60)) min")
                            .foregroundColor(.secondary)
                    }
                    Slider(
                        value: $reminderManager.blinkReminderInterval,
                        in: 15...600,
                        step: reminderManager.blinkReminderInterval < 60 ? 15 : 60
                    )
                    .onChange(of: reminderManager.blinkReminderInterval) { _ in
                        reminderManager.startTimers()
                        reminderManager.resetPopups()
                    }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Posture")
                        Spacer()
                        Text("\(Int(reminderManager.postureReminderInterval/60)) min")
                            .foregroundColor(.secondary)
                    }
                    Slider(
                        value: $reminderManager.postureReminderInterval,
                        in: 300...1800,
                        step: 300
                    )
                    .onChange(of: reminderManager.postureReminderInterval) { _ in
                        reminderManager.startTimers()
                        reminderManager.resetPopups()
                    }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Distance Focus")
                        Spacer()
                        Text("\(Int(reminderManager.distanceFocusReminderInterval/60)) min")
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Slider(
                            value: $reminderManager.distanceFocusReminderInterval,
                            in: 300...1800,
                            step: 300
                        )
                        .frame(maxWidth: .infinity)
                    }
                    .onChange(of: reminderManager.distanceFocusReminderInterval) { _ in
                        reminderManager.startTimers()
                        reminderManager.resetPopups()
                    }
                }
            } header: {
                Text("Reminder Intervals")
            }
            
            Section {
                HStack(spacing: 3) {
                    Button("Blink") {
                        reminderManager.testBlinkReminder()
                    }
                    
                    Button("Posture") {
                        reminderManager.testPostureReminder()
                    }
                    
                    Button("Distance Focus") {
                        reminderManager.testDistanceFocusReminder()
                    }
                    
                    Spacer()
                }
            } header: {
                Text("Preview Animations")
            }
            
            Section {
                HStack(spacing: 3) {
                    Button("Reset Reminders") {
                        reminderManager.resetPopups()
                    }
                    
                    Button("Quit App", role: .destructive) {
                        NSApplication.shared.terminate(nil)
                    }
                    
                    Spacer()
                }
            } header: {
                Text("App Controls")
            }
        }
        .formStyle(.grouped)
        //.padding(.all, 8) // Reduce overall padding to 8
        .frame(width: 310)
        .fixedSize(horizontal: false, vertical: true)
    }
}

// Extension to reduce section spacing
extension FormStyle where Self == GroupedFormStyle {
    static var groupedWithReducedSpacing: GroupedFormStyle {
        let style = GroupedFormStyle()
        return style
    }
}
 */
/*
// Updated Design System Components with more subtle strokes
struct SettingsCard<Content: View>: View {
    var content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content
                .padding(.vertical, 14)
                .padding(.horizontal, 14)
        }
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Material.thin)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.black.opacity(0.6), lineWidth: 0.5)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.2), lineWidth: 0.8)
                .padding(0.6)
        }
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 3)
    }
}

struct SettingsToggle: View {
    let title: String
    @Binding var isOn: Bool
    
    var body: some View {
        Toggle(isOn: $isOn) {
            Text(title)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .toggleStyle(SwitchToggleStyle(tint: Color.accentColor))
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
 */
 

// ilebButton - The original button style with new design elements
struct ilebButton: View {
    var text: String
    var destructive: Bool = false
    var action: () -> Void
    @State private var isPressed = false
    
    var body: some View {
        Text(text)
            .font(.system(size: 15, weight: .regular, design: .rounded))
            .foregroundStyle(destructive ? Color.red.opacity(0.8) : .primary)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            //.background(Material.ultraThinMaterial)
            .background(isPressed ? .black.opacity(0.1) : .black.opacity(0.01))
            .environment(\.colorScheme, .dark)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.black.opacity(0.6), lineWidth: 0.5)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(destructive ? Color.red.opacity(0.2) : Color.white.opacity(0.2), lineWidth: 0.8)
                    .padding(0.6)
            }
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressed)
            .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 3)
            // Using gestures for immediate press response
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if !isPressed {
                            isPressed = true
                        }
                    }
                    .onEnded { _ in
                        isPressed = false
                        action()
                    }
            )
            .simultaneousGesture(
                TapGesture()
                    .onEnded {
                        // This is needed to handle tap events properly
                        // The action is already called in the DragGesture.onEnded
                    }
            )
    }
}
