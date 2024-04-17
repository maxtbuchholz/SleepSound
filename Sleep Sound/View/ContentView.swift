//
//  ContentView.swift
//  SleepNoise
//
//  Created by Max Buchholz on 4/7/24.
//

import SwiftUI
import Charts
import UIKit
struct ContentView: View {
    @ObservedObject private var viewModel : AudioContentViewModel
    @State private var transparency = 0.0
    @State private var waveData : [Float]
    @State private var fftData : [Float]
    @State public var soundPlaying : Bool
    @State fileprivate var freqEQInner: [Float]//Array(repeating: Float(0.0), count: 5)
    @State private var pickedNoiseType : String
    @State private var pickedAudioFile : String
    @State private var gainSliderValue : Float
    @State var eQNeedsUpdate: Bool = false
    @State var gainNeedsUpdate: Bool = false
    fileprivate var  noiseTypes : NoiseTypes
    //private var contentClass : ContentClass
    let timer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()
    var body: some View {
        VStack {
            Image(systemName: "mic.fill")
                .imageScale(.large)
                .foregroundStyle(.tint)
            HStack{
                Picker("Noise Type", selection: $pickedNoiseType) {
                    Text("White").tag("white")
                    Text("Pink").tag("pink")
                    Text("Brown").tag("brown")
                    Text("Green").tag("green")
                    Text("Blue").tag("blue")
                }.onChange(of: pickedNoiseType) {
                    Task{
                        gainSliderValue = noiseTypes.Gains[pickedNoiseType]!
                        viewModel.gainChanged(gain: gainSliderValue)
                        freqEQInner = noiseTypes.Types[pickedNoiseType]!(viewModel.frequencies)
                        await viewModel.SpreadEQFromValues(innerFreqEQ: freqEQInner)
                    }
                }
                Picker("Audio", selection: $pickedAudioFile) {
                    Text("Noise").tag("whiteNoise")
                    Text("Rain").tag("rainWindow")
                }.onChange(of: pickedAudioFile) {
                    viewModel.changeAudioFile(audioFile: pickedAudioFile, currentlyPlaying: soundPlaying)
                }
            }
            Button{
                soundPlaying.toggle()
                viewModel.PlayPause(play: soundPlaying)
                transparency = 0.4
                withAnimation(.easeOut(duration: 0.2)){
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2){
                        transparency = 0.0
                    }
                }
            } label :{
                ZStack{
                    Circle().frame(width: 90, height: 90).opacity(transparency).tint(Color.accentColor)
                    Image(systemName: "pause.fill").font(.system(size: 64)).scaleEffect(soundPlaying ? 1 : 0).opacity(soundPlaying ? 1 : 0).animation(.interpolatingSpring(stiffness: 170, damping: 15), value: soundPlaying).tint(Color.accentColor)
                    Image(systemName: "play.fill").font(.system(size: 64)).scaleEffect(soundPlaying ? 0 : 1).opacity(soundPlaying ? 0 : 1).animation(.interpolatingSpring(stiffness: 170, damping: 15), value: !soundPlaying).tint(Color.accentColor)
                }
            }
            let waveTimer = Timer.publish(every: 0.1, on: RunLoop.main, in: .common).autoconnect()
            Chart(Array(waveData.enumerated()), id: \.0){ index, yMag in
                LineMark(
                    x: .value("index", String(index)),
                    y: .value("value", yMag)
                ).interpolationMethod(.catmullRom)
            }.foregroundColor(Color.saccent).frame(width: UIScreen.main.bounds.width, height: 200).onReceive(waveTimer, perform: updateWaveData).chartYAxis(.hidden).chartXAxis(.hidden)//.chartYScale(domain: [-0.5, 0.5])
            HStack{
                Text("Gain")
                SwiftUISlider(
                    thumbColor: .gray,
                    minTrackColor: UIColor(Color.saccent),
                    maxTrackColor: UIColor(Color.mutedAccent),
                    maximumValue: 30,
                    minimumValue: 0,
                    action: gainSliderInnerUpdateValue,
                    value: $gainSliderValue
                )
            }.contentMargins(10)
            HStack{
                //List{
                ForEach(0..<viewModel.frequencies.count) { i in
                    VStack{
                        SwiftUISlider(
                            thumbColor: .gray,
                            minTrackColor: UIColor(Color.saccent),
                            maxTrackColor: UIColor(Color.mutedAccent),
                            maximumValue: 0,
                            minimumValue: -42,
                            action: sliderInnerUpdateValue,
                            value: $freqEQInner[i]
                        ).rotationEffect(.degrees(-90.0), anchor: .topLeading)
                            .frame(width: 50, height: 100)
//                            .offset(y: 50).tint(Color.saccent).onChange(of: freqEQInner[i]) {
//                                freqEQInner = noiseTypes.Types[pickedNoiseType]!(viewModel.frequencies)
//                                viewModel.SpreadEQFromValues(innerFreqEQ: freqEQInner)
//                            }
                        Text("\(viewModel.frequencies[i])")
                    }
                    //}
                }
            }
            Spacer()
            Chart(Array(fftData.enumerated()), id: \.0){ index, yMag in
                BarMark(
                    x: .value("index", String(index)),
                    y: .value("value", yMag)
                )
            }.foregroundColor(Color.saccent).frame(width: UIScreen.main.bounds.width, height: 200).chartYAxis(.hidden).chartXAxis(.hidden).chartYScale(domain: [0, 6]).chartYScale(domain: [0, 30])
        }.frame(maxHeight: .infinity).edgesIgnoringSafeArea(.bottom) //vstack
    }
    func updateWaveData(tS : Date){
        if(eQNeedsUpdate){
            Task{
                await viewModel.SpreadEQFromValues(innerFreqEQ: freqEQInner)
            }
            eQNeedsUpdate = false
        }
        if(gainNeedsUpdate){
            viewModel.gainChanged(gain: gainSliderValue)
        }
        withAnimation(.easeOut(duration: 0.4)) {
            if(soundPlaying){
                waveData = viewModel.outWave()
                fftData = viewModel.outFFTMag()
            }else{
                waveData = Array(repeating: 0, count: waveData.count)
                fftData = Array(repeating: 0, count: fftData.count)
            }
        }
    }
    init() {
        self.transparency = 0.0
        self.waveData = Array(repeating: 0, count: 400)
        self.fftData  = Array(repeating: 0, count: 40)
        self.soundPlaying = false
        self.noiseTypes = NoiseTypes.init()
        self.pickedNoiseType  = "pink"
        self.pickedAudioFile = "whiteNoise"
        self.freqEQInner = [0, -6, -9, -12, -18, -21]
        self.gainSliderValue = Float(15)
        self.viewModel = AudioContentViewModel.init(audioFile: "whiteNoise")
//        self.contentClass = ContentClass.init()
//        self.contentClass.SetValues(freqEQInner: &freqEQInner, viewModel: viewModel, pickedNoiseType: &pickedNoiseType)
    }
    func sliderInnerUpdateValue() async{
        eQNeedsUpdate = true
    }
    func gainSliderInnerUpdateValue() async{
        gainNeedsUpdate = true
    }
}
#Preview {
    ContentView()
}
//class ContentClass{
//
//    func SetValues(freqEQInner: inout [Float], viewModel: AudioContentViewModel, pickedNoiseType: inout String){
//        self.freqEQInner =  freqEQInner
//        self.viewModel = viewModel
//        self.pickedNoiseType = pickedNoiseType
//    }
//    var viewModel: AudioContentViewModel = AudioContentViewModel.init()
//    var freqEQInner: [Float] = []
//    var noiseTypes : NoiseTypes = NoiseTypes.init()
//    var pickedNoiseType: String = ""
//    @objc func UpdateEQSlider(){
//        freqEQInner = noiseTypes.Types[pickedNoiseType]!(viewModel.frequencies)
//        viewModel.SpreadEQFromValues(innerFreqEQ: freqEQInner)
//    }
//}
