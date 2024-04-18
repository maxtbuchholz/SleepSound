import SwiftUI
struct SwiftUISlider: UIViewRepresentable {

  final class Coordinator: NSObject {
    @State var value: Binding<Float>
    init(value: Binding<Float>) {
      self.value = value
    }
      @objc func valueChanged(_ sender: UISlider) {
      self.value.wrappedValue = Float(sender.value)
    }
  }

  var thumbColor: UIColor = .white
  var minTrackColor: UIColor? = .white
  var maxTrackColor: UIColor? = .white
  var maximumValue: Float = 1
  var minimumValue: Float = 0
    var action: () async -> Void

  @Binding var value: Float

  func makeUIView(context: Context) -> UISlider {
      let slider = UISlider(frame: .zero)
      slider.tintColor = minTrackColor
      slider.maximumTrackTintColor = maxTrackColor
      slider.thumbTintColor = thumbColor
      slider.value = value
      slider.minimumValue = minimumValue
      slider.maximumValue = maximumValue
      slider.isContinuous = true
      slider.layer.shadowRadius = 0
      //slider.transform = CGAffineTransform(rotationAngle: CGFloat(-Double.pi/2))
      //slider.backgroundColor = UIColor.green

    slider.addTarget(
      context.coordinator,
      action: #selector(Coordinator.valueChanged(_:)),
      for: .valueChanged
    )

    return slider
  }

  func updateUIView(_ uiView: UISlider, context: Context) {
    uiView.value = Float(self.value)
      Task{
          await action()
      }
  }

  func makeCoordinator() -> SwiftUISlider.Coordinator {
    Coordinator(value: $value)
  }
}
