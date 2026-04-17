import SwiftUI

enum LottieLoopMode { case loop, playOnce, autoReverse }

struct LottieView: View {
    let name: String
    var loopMode: LottieLoopMode = .loop
    var animationSpeed: CGFloat = 1.0

    var body: some View {
        Color.clear
    }
}
