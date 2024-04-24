//
//  ContentView.swift
//  SleepNoise
//
//  Created by Max Buchholz on 4/7/24.
//

import SwiftUI
import Charts
import UIKit
import Accelerate
struct ContentView: View {
    @ObservedObject private var viewModel : AudioContentViewModel
    @State private var transparency = 0.0
    @State private var waveData : [Float] = Array(repeating: 0, count: 100)
    @State private var fftData : [Float] = Array(repeating: 0, count: 30)
    @State private var longTimeWaveData : [Float] = Array(repeating: 0, count: 50)
    @State private var longTimeFftData : [Float] = Array(repeating: 0, count: 30)
    @State private var prevLongTimeWaveData : [Float] = Array(repeating: 0, count: 50)
    @State private var prevLongTimeFftData : [Float] = Array(repeating: 0, count: 30)
    @State public var soundPlaying : Bool = false
    @State fileprivate var freqEQInner: [Float] = [0, -3, -6, -9, -12, -15, -18, -21]
    @State private var pickedNoiseType : String = "pink"
    @State private var pickedAudioFile : String = "whiteNoise"
    @State private var gainSliderValue : Float = Float(15)
    @State var eQNeedsUpdate: Bool = false
    @State var gainNeedsUpdate: Bool = false
    @State var backgroundRotation = 0.0
    @State var timePickerTime : Date = Date.now
    @State var BottomPickerTime : Date = Date.now
    @State var seconds = 15
    @State var hoursLeft = 0
    @State var minutesLeft = 0
    @State var secondsLeft = 0
    @State var mainTimer = Timer.publish(every: TimeInterval(Int.max), on: .main, in: .common).autoconnect()
    private var  noiseTypes : NoiseTypes = NoiseTypes.init()
    //var timer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()
    var body: some View {
        VStack {
            ZStack{
                GeometryReader{ proxy in
                    let size = proxy.size
                    Circle()
                        .fill(Color.squinary)
                        .padding(20)
                        .blur(radius: 250)
                        .offset(x: -size.width/5, y: -size.height/5)
                    Circle()
                        .fill(Color.stertiary)
                        .padding(20)
                        .blur(radius: 200)
                        .offset(x: size.width/1.8, y: size.height/3)
                    Circle()
                        .fill(Color.squaternary)
                        .padding(20)
                        .blur(radius: 200)
                        .offset(x: -size.width/4, y: size.height/2)
                }.rotationEffect(Angle(degrees: backgroundRotation))
                VStack{
                    HStack{
                        Picker("Noise Type", selection: $pickedNoiseType) {
                            Text("White").tag("white")
                            Text("Pink").tag("pink")
                            Text("Brown").tag("brown")
                            Text("Green").tag("green")
                            Text("Blue").tag("blue")
                            Text("Violet").tag("violet")
                        }.tint(Color.splain).overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(Color.splain, lineWidth: 1).fill(.white).opacity(0.1).allowsHitTesting(false)
                        ).onChange(of: pickedNoiseType) {
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
                        }.tint(Color.splain).overlay(
                            RoundedRectangle(cornerRadius: 10).stroke(Color.splain, lineWidth: 1).fill(.white).opacity(0.1).allowsHitTesting(false)
                        ).onChange(of: pickedAudioFile) {
                            viewModel.changeAudioFile(audioFile: pickedAudioFile, currentlyPlaying: soundPlaying)
                        }
                    }
                    ZStack
                    {
                        Text("\(toTimeString(num: hoursLeft)):\(toTimeString(num: minutesLeft)):\(toTimeString(num: secondsLeft))").foregroundStyle(soundPlaying ? Color.sdisabled_text : Color.plain).font(.system(size: 40)).padding(10).overlay(
                            RoundedRectangle(cornerRadius: 10).stroke(Color.splain, lineWidth: 1).fill(.white).opacity(0.1).allowsHitTesting(false)
                        ).overlay(
                            DatePicker("", selection: $timePickerTime, displayedComponents: .hourAndMinute)
                                .datePickerStyle(CompactDatePickerStyle())
                                .clipped()
                                .labelsHidden()
                                .scaleEffect(2.1)
                                .opacity(0.02)
                                .environment(\.locale, .init(identifier: "de"))
                                .accentColor(.clear)
                                .disabled(soundPlaying)
                                .onTapGesture{
                                    let baseCalendar = Calendar.current
                                    var baseComponents = DateComponents()
                                    baseComponents.year = 2000
                                    baseComponents.month = 1
                                    baseComponents.day = 1
                                    baseComponents.hour = 0
                                    baseComponents.minute = 0
                                    baseComponents.second = 0
                                    BottomPickerTime = baseCalendar.date(from: baseComponents)!
                                    let calendar = Calendar.current
                                    var components = DateComponents()
                                    components.year = 2000
                                    components.month = 1
                                    components.day = 1
                                    components.hour = hoursLeft
                                    components.minute = minutesLeft
                                    components.second = secondsLeft
                                    timePickerTime = calendar.date(from: components)!
                                }
                                .onChange(of: timePickerTime) {
                                    let difference = Calendar.current.dateComponents([.hour, .minute], from: BottomPickerTime, to: timePickerTime)
                                    hoursLeft = difference.hour ?? 0
                                    minutesLeft = difference.minute ?? 0
                                    secondsLeft = 00

                                }.onReceive(mainTimer) { _ in
                                    if(secondsLeft > 0){
                                        secondsLeft -= 1
                                    } else if(minutesLeft > 0){
                                        minutesLeft -= 1
                                        secondsLeft = 59
                                    } else if(hoursLeft > 0){
                                        hoursLeft -= 1
                                        minutesLeft = 59
                                        secondsLeft = 59
                                    } else{
                                        secondsLeft = 0
                                        minutesLeft = 0
                                        hoursLeft = 0
                                        soundPlaying = false
                                        viewModel.PlayPause(play: soundPlaying)
                                    }
                                }.onChange(of: soundPlaying) {
                                    if(soundPlaying && ((hoursLeft + minutesLeft + secondsLeft) > 0)){
                                        mainTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
                                    }else{
                                        mainTimer.upstream.connect().cancel()
                                    }
                                }
                        )
                    }
                    ZStack{
                        Chart(Array(waveData.enumerated()), id: \.0){ index, yMag in
                            LineMark(
                                x: .value("index", index),
                                y: .value("value", yMag)
                            ).interpolationMethod(.catmullRom)
                        }.foregroundColor(Color.squinary).frame(width: UIScreen.main.bounds.width, height: 200)
                            //.onReceive(waveTimer, perform: updateWaveData)
                            .chartYAxis(.hidden).chartXAxis(.hidden).chartXScale(domain: [0, 99]).onAppear{updateWaveData(tS: Date.now)}
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
                                Circle().frame(width: 110, height: 110).opacity(transparency).tint(Color.saccent)
                                Image(systemName: "pause.fill").font(.system(size: 64)).scaleEffect(soundPlaying ? 1 : 0).opacity(soundPlaying ? 1 : 0).animation(.interpolatingSpring(stiffness: 170, damping: 15), value: soundPlaying).tint(Color.splain)
                                Image(systemName: "play.fill").font(.system(size: 64)).scaleEffect(soundPlaying ? 0 : 1).opacity(soundPlaying ? 0 : 1).animation(.interpolatingSpring(stiffness: 170, damping: 15), value: !soundPlaying).tint(Color.splain)
                            }//.overlay(Circle().stroke(Color.splain, lineWidth: 1)).background(Color.sbackground)
                        }
                    }.frame(maxHeight: UIScreen.main.bounds.size.height / 6)
                    HStack{
                        Text("Gain")
                        SwiftUISlider(
                            thumbColor: UIColor.white,
                            minTrackColor: UIColor.gray,
                            maxTrackColor: UIColor.lightGray,
                            maximumValue: 30,
                            minimumValue: 0,
                            action: gainSliderInnerUpdateValue,
                            value: $gainSliderValue
                        )
                    }.padding(EdgeInsets(top: -5, leading: 15, bottom: -5, trailing: 15))
                    VStack{
                        VStack{
                            ForEach(0..<viewModel.frequencies.count) { i in
                                HStack{
                                    SwiftUISlider(
                                        thumbColor: UIColor.white,
                                        minTrackColor: UIColor.gray,
                                        maxTrackColor: UIColor.lightGray,
                                        maximumValue: 0,
                                        minimumValue: -42,
                                        action: sliderInnerUpdateValue,
                                        value: $freqEQInner[i]
                                    )
                                    Text(toStringWithLength(num: viewModel.frequencies[i], length: 5))
                                }.padding(.leading, 20)
                                    .padding(.trailing, 20)
                            }
                        }.padding(.top, 10).padding(.bottom, 10)
                    }.frame(maxHeight: .infinity)//.background(Color.sbackground)
                        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.splain, lineWidth: 1).fill(.white).opacity(0.1).shadow(radius: 10).allowsHitTesting(false))
                        .padding(EdgeInsets(top: 0, leading: 15, bottom: 0, trailing: 15))
                    Spacer()
                    Chart(Array(fftData.enumerated()), id: \.0){ index, yMag in
                        BarMark(
                            x: .value("index", index),
                            y: .value("value", yMag),
                            width: .fixed(UIScreen.main.bounds.size.width / 40)
                        )
                    }.foregroundColor(Color.squinary).chartYAxis(.hidden).chartXAxis(.hidden).chartYScale(domain: [0, 8]).chartXScale(domain: [0, 29]).frame(maxHeight: .infinity).edgesIgnoringSafeArea(.bottom)
                }.frame(maxHeight: .infinity).edgesIgnoringSafeArea(.bottom)
            }
        }
    }
    func updateWaveData(tS : Date){
        backgroundRotation += 1
        if(eQNeedsUpdate){
            Task{
                await viewModel.SpreadEQFromValues(innerFreqEQ: freqEQInner)
            }
            eQNeedsUpdate = false
        }
        if(gainNeedsUpdate){
            viewModel.gainChanged(gain: gainSliderValue)
            gainNeedsUpdate = false
        }
        withAnimation(.linear(duration: 0.18)) {
            
            if(soundPlaying){
                waveData = viewModel.outWave()
                fftData = viewModel.outFFTMag()
            }else{
                waveData = Array(repeating: 0, count: waveData.count)
                fftData = Array(repeating: 0, count: fftData.count)
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
            updateWaveData(tS: Date.now)
        }
    }
    //let waveTimer = Timer.publish(every: 0.2, on: RunLoop.main, in: .common).autoconnect()
    private func toStringWithLength(num: Int, length: Int) -> String {
        var sNum = "\(num)"
        for i in sNum.count..<(length){
            sNum = " " + sNum
        }
        return sNum
    }
    private func toTimeString(num: Int) -> String {
        var sNum = "\(num)"
        for i in sNum.count..<(2){
            sNum = "0" + sNum
        }
        return sNum
    }
    init() {
        self.viewModel = AudioContentViewModel.init(audioFile: "whiteNoise")
        self.waveData = Array(repeating: 0, count: 400)
        self.fftData  = Array(repeating: 0, count: 40)
        self.soundPlaying = false
        self.freqEQInner = [0, -6, -9, -12, -18, -21]
        self.pickedNoiseType  = "pink"
        self.pickedAudioFile = "whiteNoise"
        self.gainSliderValue = Float(15)
        self.transparency = 0.0
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
