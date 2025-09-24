//
//  ContentView.swift
//  ex4
//
//  Created by Yutong Jiang on 9/19/25.
//

import SwiftUI
import UIKit

struct ContentView: View {
    @State private var showMain = false

    var body: some View {
        ZStack {
            if showMain {
                MainLoomView(onExit: {
                    withAnimation(.easeInOut(duration: 0.35)) { showMain = false }
                })
                .transition(.move(edge: .trailing).combined(with: .opacity))
            } else {
                WelcomeView {
                    withAnimation(.easeInOut(duration: 0.35)) { showMain = true }
                }
                .transition(.move(edge: .leading).combined(with: .opacity))
            }
        }
    }
}

struct WelcomeView: View {
    var onStart: () -> Void

    var body: some View {
        ZStack {
            LinearGradient(gradient: Gradient(colors: [.black.opacity(0.9), .black]),
                           startPoint: .topLeading,
                           endPoint: .bottomTrailing)
                .ignoresSafeArea()
            VStack(spacing: 24) {
                Text("Touch Loom")
                    .font(.system(size: 38, weight: .bold))
                    .foregroundStyle(.white.opacity(0.95))
                Text("Pin nodes, connect threads, and progress through runs.")
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
                Button(action: onStart) {
                    Text("Let's Go!")
                        .font(.headline)
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .shadow(radius: 12)
                }
                .padding(.horizontal, 40)
            }
        }
    }
}

struct MainLoomView: View {
    var onExit: () -> Void

    @State private var touches: [String: CGPoint] = [:]
    @State private var touchStart: [String: Date] = [:]
    @State private var nodes: [CGPoint] = []
    @State private var brush: CGFloat = 40
    @State private var ripples: [UUID: (center: CGPoint, birth: Date)] = [:]

    @State private var level: Int = 1
    @State private var goal: Int = 4
    @State private var tokens: Int = 0
    @State private var showingCompletion: Bool = false

    @GestureState private var pinch: CGFloat = 1

    let holdThreshold: TimeInterval = 0.6

    let zodiac: [(name: String, prompt: String)] = [
        ("Aries",       "Make the Aries sign"),
        ("Taurus",      "Make the Taurus sign"),
        ("Gemini",      "Make the Gemini sign"),
        ("Cancer",      "Make the Cancer sign"),
        ("Leo",         "Make the Leo sign"),
        ("Virgo",       "Make the Virgo sign"),
        ("Libra",       "Make the Libra sign"),
        ("Scorpio",     "Make the Scorpio sign"),
        ("Sagittarius", "Make the Sagittarius sign"),
        ("Capricorn",   "Make the Capricorn sign"),
        ("Aquarius",    "Make the Aquarius sign"),
        ("Pisces",      "Make the Pisces sign")
    ]

    var currentZodiac: (name: String, prompt: String) { zodiac[(level - 1) % zodiac.count] }
    var nextZodiac: (name: String, prompt: String)     { zodiac[level % zodiac.count] }

    var body: some View {
        GeometryReader { _ in
            ZStack {
                gameLayer
                    .allowsHitTesting(!showingCompletion)

                if showingCompletion {
                    completionOverlay
                        .transition(.opacity)
                }
            }
        }
    }

    private var gameLayer: some View {
        let displayBrush = min(max(brush * pinch, 16), 120)

        return ZStack {
            LinearGradient(gradient: Gradient(colors: [.black.opacity(0.9), .black]),
                           startPoint: .topLeading,
                           endPoint: .bottomTrailing)
                .ignoresSafeArea()

            let threadGradient = LinearGradient(
                colors: [.cyan.opacity(0.6), .indigo.opacity(0.6), .pink.opacity(0.6)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )

            Path { path in
                guard nodes.count > 1 else { return }
                path.move(to: nodes[0])
                for p in nodes.dropFirst() { path.addLine(to: p) }
            }
            .stroke(threadGradient, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
            .blur(radius: 0.5)

            ForEach(Array(nodes.enumerated()), id: \.offset) { _, p in
                ZStack {
                    Circle().fill(.white.opacity(0.85)).frame(width: 12, height: 12)
                    Circle().stroke(.white.opacity(0.6), lineWidth: 2).frame(width: 16, height: 16).blur(radius: 1)
                    Circle().fill(.cyan.opacity(0.35)).frame(width: 38, height: 38).blur(radius: 6)
                }
                .position(p)
            }

            ForEach(Array(touches.keys), id: \.self) { key in
                if let p = touches[key] {
                    let progress = holdProgress(for: key)
                    ZStack {
                        Circle()
                            .fill(.white.opacity(0.12))
                            .frame(width: displayBrush * 2, height: displayBrush * 2)
                            .shadow(color: .white.opacity(0.15), radius: 14)
                        Circle()
                            .strokeBorder(.white.opacity(0.35), lineWidth: 2)
                            .frame(width: displayBrush * (1 + progress), height: displayBrush * (1 + progress))
                            .scaleEffect(1 + 0.03 * sin(Date().timeIntervalSinceReferenceDate))
                        Circle()
                            .fill(.white.opacity(0.8))
                            .frame(width: max(8, displayBrush * 0.35), height: max(8, displayBrush * 0.35))
                    }
                    .position(p)
                    .animation(.easeOut(duration: 0.12), value: p)
                }
            }

            TimelineView(.animation) { timeline in
                let now = timeline.date
                ZStack {
                    ForEach(Array(ripples.keys), id: \.self) { key in
                        if let r = ripples[key] {
                            let age = now.timeIntervalSince(r.birth)
                            let progress = min(max(age / 0.8, 0), 1)
                            Circle()
                                .stroke(.white.opacity(1 - progress), lineWidth: max(1, 6 * (1 - progress)))
                                .frame(width: 12 + 140 * progress, height: 12 + 140 * progress)
                                .position(r.center)
                                .blendMode(.screen)
                        }
                    }
                }
            }

            VStack(spacing: 8) {
                HStack {
                    Button(action: onExit) {
                        Text("Home")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.black)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 14)
                            .background(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .shadow(radius: 8)
                    }
                    Spacer()
                    HStack(spacing: 14) {
                        Label("Lvl \(level)", systemImage: "flag.checkered")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.9))
                        Label("Goal \(goal)", systemImage: "target")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.9))
                        Label("Tokens \(tokens)", systemImage: "seal")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.9))
                    }
                }
                .padding(.horizontal, 16)

                Text(currentZodiac.prompt)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.9))

                Text("Hold ~1s to pin • Pinch to resize • Double-tap to clear")
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.8))
            }
            .padding(.top, 18)
            .frame(maxHeight: .infinity, alignment: .top)
        }
        .gesture(
            SpatialEventGesture()
                .onChanged { events in
                    for e in events {
                        let key = "\(e.id)"
                        touches[key] = e.location
                        if touchStart[key] == nil { touchStart[key] = Date() }
                        if let start = touchStart[key],
                           Date().timeIntervalSince(start) >= holdThreshold {
                            pinNode(at: e.location)
                            touchStart[key] = Date.distantFuture
                        }
                    }
                }
                .onEnded { events in
                    for e in events {
                        let key = "\(e.id)"
                        touches[key] = nil
                        touchStart[key] = nil
                    }
                }
        )
        .simultaneousGesture(
            MagnificationGesture()
                .updating($pinch) { value, state, _ in state = value }
                .onEnded { value in brush = min(max(brush * value, 16), 120) }
        )
        .simultaneousGesture(
            TapGesture(count: 2).onEnded { clearAll() }
        )
        .onChange(of: nodes.count) { newValue in
            if !showingCompletion && newValue >= goal {
                tokens += 1
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { showingCompletion = true }
            }
        }
    }

    private var completionOverlay: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()
            VStack(spacing: 16) {
                Text("Weave Complete")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)
                Text("+1 Thread Token")
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.85))
                Text("Next: \(nextZodiac.name)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.9))
                HStack(spacing: 12) {
                    Button(action: { onExit() }) {
                        Text("Home")
                            .font(.headline)
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .shadow(radius: 10)
                    }
                    Button(action: continueRun) {
                        Text("Continue")
                            .font(.headline)
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .shadow(radius: 10)
                    }
                }
                .padding(.horizontal, 24)
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.black.opacity(0.35))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(LinearGradient(colors: [.cyan.opacity(0.6), .indigo.opacity(0.6), .pink.opacity(0.6)],
                                                   startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 2)
                    )
            )
            .padding(.horizontal, 24)
        }
    }

    func holdProgress(for key: String) -> CGFloat {
        guard let start = touchStart[key] else { return 0 }
        let t = Date().timeIntervalSince(start)
        return CGFloat(min(max(t / holdThreshold, 0), 1))
    }

    func pinNode(at point: CGPoint) {
        nodes.append(point)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        let id = UUID()
        ripples[id] = (point, Date())
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.85) { ripples[id] = nil }
    }

    func clearAll() {
        nodes.removeAll()
        touches.removeAll()
        touchStart.removeAll()
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
    }

    func continueRun() {
        level += 1
        goal = min(goal + 2, 24)
        clearAll()
        withAnimation(.easeOut(duration: 0.25)) { showingCompletion = false }
    }
}

#Preview {
    ContentView()
}
