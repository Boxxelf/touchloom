//
//  ContentView.swift
//  ex4
//
//  Created by Yutong Jiang on 9/19/25.
//

import SwiftUI

struct ContentView: View {
    @State private var showMain = false

    var body: some View {
        ZStack {
            if showMain {
                MainLoomView()
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
                Text("Use touch duration, multi-touch, and gestures to weave an interactive canvas.")
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
                Button(action: onStart) {
                    Text("Start")
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
    @State private var touches: [String: CGPoint] = [:]
    @State private var touchStart: [String: Date] = [:]
    @State private var nodes: [CGPoint] = []
    @State private var brush: CGFloat = 40
    @State private var ripples: [UUID: (center: CGPoint, birth: Date)] = [:]
    private let holdThreshold: TimeInterval = 0.6

    var body: some View {
        GeometryReader { _ in
            ZStack {
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
                        Circle()
                            .fill(.white.opacity(0.85))
                            .frame(width: 12, height: 12)
                        Circle()
                            .stroke(.white.opacity(0.6), lineWidth: 2)
                            .frame(width: 16, height: 16)
                            .blur(radius: 1)
                        Circle()
                            .fill(.cyan.opacity(0.35))
                            .frame(width: 38, height: 38)
                            .blur(radius: 6)
                    }
                    .position(p)
                }

                ForEach(Array(touches.keys), id: \.self) { key in
                    if let p = touches[key] {
                        let progress = holdProgress(for: key)
                        ZStack {
                            Circle()
                                .fill(.white.opacity(0.12))
                                .frame(width: brush * 2, height: brush * 2)
                                .shadow(color: .white.opacity(0.15), radius: 14, x: 0, y: 0)
                            Circle()
                                .strokeBorder(.white.opacity(0.35), lineWidth: 2)
                                .frame(width: brush * (1 + progress), height: brush * (1 + progress))
                                .scaleEffect(1 + 0.03 * sin(Date().timeIntervalSinceReferenceDate))
                            Circle()
                                .fill(.white.opacity(0.8))
                                .frame(width: max(8, brush * 0.35), height: max(8, brush * 0.35))
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
                                    .stroke(.white.opacity(1 - progress),
                                            lineWidth: max(1, 6 * (1 - progress)))
                                    .frame(width: 12 + 140 * progress, height: 12 + 140 * progress)
                                    .position(r.center)
                                    .blendMode(.screen)
                            }
                        }
                    }
                }

                VStack {
                    Text("Touch Loom")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.9))
                    Text("Hold ~0.6s to pin • Pinch to resize • Double-tap to clear")
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.6))
                }
                .padding(.top, 24)
                .frame(maxHeight: .infinity, alignment: .top)
            }
            .gesture(
                SpatialEventGesture()
                    .onChanged { events in
                        for e in events {
                            let key = "\(e.id)"
                            touches[key] = e.location
                            if touchStart[key] == nil {
                                touchStart[key] = Date()
                            }
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
            .gesture(
                MagnificationGesture()
                    .onChanged { scale in
                        let newSize = brush * scale
                        brush = min(max(newSize, 16), 120)
                    }
            )
            .simultaneousGesture(
                TapGesture(count: 2)
                    .onEnded { clearAll() }
            )
        }
    }

    private func holdProgress(for key: String) -> CGFloat {
        guard let start = touchStart[key] else { return 0 }
        let t = Date().timeIntervalSince(start)
        return CGFloat(min(max(t / holdThreshold, 0), 1))
    }

    private func pinNode(at point: CGPoint) {
        nodes.append(point)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        let id = UUID()
        ripples[id] = (point, Date())
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.85) {
            ripples[id] = nil
        }
    }

    private func clearAll() {
        nodes.removeAll()
        touches.removeAll()
        touchStart.removeAll()
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
    }
}



#Preview {
    ContentView()
}
