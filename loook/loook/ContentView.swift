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
                    .blur(radius: frameBlur)
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
            // Move up to keep top aligned
        }
        
        // Frame settles with less blur
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                frameScale = 1.0
                frameBlur = 0
                circleBlur = 0
                //frameHeight = 130
                //frameOffsetY = 5
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
        
        // 4. Playful exit animation - pill morphs into circle
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            // First a slight "prepare to exit" animation
            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                frameScale = 1.05
                circleScale = 1.05
                arrowScale = 1.05
                frameBlur = 2
            }
            
            // Then begin the playful exit - pill starts morphing to circle
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    // Morph pill to circle by reducing height and adjusting position
                    frameHeight = 80
                    frameOffsetY = 20 // Move up to keep top aligned
                    circleOffset = 20
                    
                    
                    // Add blur as transition begins
                    frameBlur = 3
                    circleBlur = 3
                    arrowBlur = 3
                    circleOpacity = 0.8
                    circleScale = 0.8
                    frameScale = 0.85
                    arrowScale = 0.85
                }
                
                // Final bounce-out and fade with increasing blur
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.23) {
                    withAnimation(.easeOut(duration: 0.2)) {
                        // Everything scales slightly up before disappearing
                        frameScale = 0.6
                        circleScale = 0.1
                        arrowScale = 0.1
                        
                        // Move everything up slightly
                        frameOffsetY = frameOffsetY - 5
                        circleOffset = circleOffset - 5
                        
                        // Then quickly fade with heavy blur
                        frameBlur = 6
                        circleBlur = 6
                        frameOpacity = 0
                        circleOpacity = 0
                        arrowOpacity = 0
                        arrowBlur = 6
                    }
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                        isShowing = false
                    }
                }
            }
        }
    }
}
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
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                eyeScale = 1.0
                eyeOpacity = 1
                eyeBlur = 0
            }
            
            // First playful bounce - eye "blinks"
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                withAnimation(.spring(response: 0.15, dampingFraction: 0.8)) {
                    //eyeScale = 0.9 // Eye slightly closes
                }
                
                // Open eye with bounce
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        eyeScale = 0.8 // Eye opens wider
                        circleScale = 1.08 // Circle reacts slightly
                                           //frameScale = 1.04 // Frame reacts slightly
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
                                //frameScale = 1.0
                                eyeColor = .black
                                circleColor = .white
                                eyeBlur = 0
                            }
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.39) {
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.9)) {
                                frameScale = 1.0 // Frame reacts slightly
                            }
                            /*
                             // Second playful bounce after a pause
                             DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                             withAnimation(.spring(response: 0.4, dampingFraction: 0.55)) {
                             eyeBounce = -4 // Eye moves slightly up
                             eyeScale = 1.1
                             circleScale = 1.05
                             }
                             
                             // Return to position
                             DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                             withAnimation(.spring(response: 0.35, dampingFraction: 0.65)) {
                             eyeBounce = 0
                             eyeScale = 1.0
                             circleScale = 1.0
                             }
                             }
                             }
                             */
                        }
                    }
                }
            }
        }
        
        // 4. Playful exit animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.3) {
            // Prepare to exit - slight pulse
            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                frameScale = 1.05
                circleScale = 1.07
                eyeScale = 1.05
            }
            
            // Begin exit animation
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                // Eye disappears first with quick scale down
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    eyeScale = 0.7
                    eyeOpacity = 0.5
                    eyeBlur = 2
                }
                
                // Then circle and frame shrink and fade
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) {
                        // Circle shrinks faster than frame
                        circleScale = 0.5
                        circleOpacity = 0.4
                        circleBlur = 4
                        eyeScale = 0.3
                        eyeOpacity = 0
                        eyeBlur = 5
                    }
                    
                    // Final disappearing animation
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        withAnimation(.easeOut(duration: 0.25)) {
                            frameScale = 0.6
                            frameOpacity = 0
                            frameBlur = 8
                            circleScale = 0.3
                            circleOpacity = 0
                            circleBlur = 8
                        }
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            isShowing = false
                        }
                    }
                }
            }
        }
    }
}

// Updated Countdown Reminder View with new design language
struct CountdownReminderView: View {
    @Binding var isShowing: Bool
    @Binding var secondsRemaining: Int
    @State private var isHovering = false
    @State private var frameOpacity: Double = 0
    @State private var frameBlur: CGFloat = 10
    @State private var frameScale: CGFloat = 0.9
    @State private var textOpacity: Double = 0
    @State private var textScale: CGFloat = 0.8
    
    var body: some View {
        ZStack {
            // Horizontal pill with new design
            Capsule(style: .continuous)
                .fill(Material.ultraThinMaterial)
                .frame(width: 140, height: 60)
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
                .opacity(frameOpacity)
                .blur(radius: frameBlur)
                .scaleEffect(frameScale)
            
            // Content with countdown and dismiss button
            HStack(spacing: 8) {
                // Countdown text
                Text("\(secondsRemaining)s")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(.primary)
                    .contentTransition(.numericText())
                    .opacity(textOpacity)
                    .scaleEffect(textScale)
                    .animation(.spring(response: 0.35, dampingFraction: 0.8), value: secondsRemaining)
                
                // Dismiss button (only visible on hover)
                if isHovering {
                    Button {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                            // First make the text bounce out
                            textScale = 1.1
                            textOpacity = 0
                            
                            // Then the frame
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.7).delay(0.1)) {
                                frameScale = 1.05
                                frameOpacity = 0
                                frameBlur = 5
                            }
                            
                            // Notify after animations
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                isShowing = false
                                NotificationCenter.default.post(name: NSNotification.Name("CountdownDismissed"), object: nil)
                            }
                        }
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
        }
        .environment(\.colorScheme, .dark)
        .onAppear {
            // Initial state
            frameOpacity = 0
            frameBlur = 10
            frameScale = 0.9
            textOpacity = 0
            textScale = 0.8
            
            // 1. Animate in the frame with blur
            withAnimation(.easeOut(duration: 0.3)) {
                frameOpacity = 1
                frameBlur = 0
                frameScale = 1.0
            }
            
            // 2. Animate in the text with slight delay
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.1)) {
                textOpacity = 1
                textScale = 1.0
            }
            
            // 3. Add observer for dismissal notification
            NotificationCenter.default.addObserver(
                forName: NSNotification.Name("CountdownDismissed"),
                object: nil,
                queue: .main
            ) { _ in
                DispatchQueue.main.async {
                    withAnimation {
                        self.isShowing = false
                    }
                }
            }
            
            // 4. Auto-dismiss when countdown reaches zero
            if secondsRemaining == 0 {
                // First bounce the text
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    textScale = 1.1
                    textOpacity = 0
                }
                
                // Then bounce and fade the frame
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.1)) {
                    frameScale = 1.05
                    frameOpacity = 0
                    frameBlur = 5
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

// Updated Settings View with more subtle strokes
struct SettingsView: View {
    @ObservedObject var reminderManager: ReminderManager
    @Binding var isPresented: Bool
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                // Header
                Text("Settings")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
                
                // Settings content
                VStack(alignment: .leading, spacing: 8) {
                    // Toggle section
                    SettingsCard {
                        VStack(alignment: .leading, spacing: 12) {
                            SettingsToggle(title: "Enable Reminders", isOn: $reminderManager.isRemindersEnabled)
                                .onChange(of: reminderManager.isRemindersEnabled) { _ in
                                    reminderManager.startTimers()
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            SettingsToggle(title: "Launch at Login", isOn: $reminderManager.launchAtLogin)
                                .onChange(of: reminderManager.launchAtLogin) { _ in
                                    reminderManager.toggleLaunchAtLogin()
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    
                    // Sliders section
                    SettingsCard {
                        VStack(alignment: .leading, spacing: 18) {
                            Text("Reminder Intervals")
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                                .foregroundColor(.secondary)
                            
                            // Posture reminder: 5-30 minutes in 5-minute steps
                            SettingsSlider(
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
                            SettingsSlider(
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
                            SettingsSlider(
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
                    SettingsCard {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Preview Animations")
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                                .foregroundColor(.secondary)
                            
                            VStack(spacing: 8) {
                                ilebButton(text: "Posture") {
                                    reminderManager.testPostureReminder()
                                }
                                
                                ilebButton(text: "Blink") {
                                    reminderManager.testBlinkReminder()
                                }
                                
                                ilebButton(text: "Distance Focus") {
                                    reminderManager.testDistanceFocusReminder()
                                }
                            }
                        }
                    }
                    
                    // Reset & Quit section
                    SettingsCard {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("App Controls")
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                                .foregroundColor(.secondary)
                            
                            VStack(spacing: 8) {
                                ilebButton(text: "Reset Pop-ups") {
                                    reminderManager.resetPopups()
                                }
                                
                                ilebButton(text: "Close") {
                                    isPresented = false
                                }
                                
                                ilebButton(text: "Quit App", destructive: true) {
                                    NSApplication.shared.terminate(nil)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 8)
            }
            .padding(.vertical, 8)
        }
        .frame(width: 320)
        /*
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Material.ultraThinMaterial)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.black.opacity(0.6), lineWidth: 0.5)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.2), lineWidth: 0.8)
                .padding(0.6)
        }
        .environment(\.colorScheme, .dark)
        .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 3)
         */
    }
}

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
