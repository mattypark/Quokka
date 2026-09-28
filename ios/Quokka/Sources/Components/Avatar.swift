import SwiftUI
import QuokkaDesign

/// A round picture, or the first letter of the name on grey when there is none.
struct Avatar: View {
    let image: UIImage?
    let name: String
    var size: CGFloat = 56

    private var initial: String {
        name.trimmingCharacters(in: .whitespaces).first.map { String($0).uppercased() } ?? ""
    }

    var body: some View {
        ZStack {
            Surface.control
            if let image {
                Image(uiImage: image).resizable().aspectRatio(contentMode: .fill)
            } else if !initial.isEmpty {
                Text(initial)
                    .font(.system(size: size * 0.42, weight: .medium))
                    .foregroundStyle(Label.secondary)
            } else {
                Image(systemName: "person.fill")
                    .font(.system(size: size * 0.42))
                    .foregroundStyle(Label.dim)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .accessibilityHidden(true)
    }
}
