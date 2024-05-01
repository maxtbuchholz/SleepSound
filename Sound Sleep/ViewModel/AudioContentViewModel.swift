//
//  ContentViewModel.swift
//  Sleep Sound
//
//  Created by Max Buchholz on 4/13/24.
//

import Foundation
import AVFoundation

class AudioContentViewModel: ObservableObject {
    public var backFrequencies: [Int] = [63, 94, 125, 187, 250, 375, 500, 750, 1000, 1500, 2000, 3000, 4000, 6000, 8000, 12000, 16000, 20000]
    private var freqEQOuter: [Float] = Array(repeating: Float(0.0), count: 17)
    public var frequencies: [Int] = [125, 250, 500, 1000, 2000, 4000, 8000, 16000]
    @Published var audio : Audio
    private var logarithmicBinsFreq : [Float] = []
    private var linearToLogarithmicBins : [[Int]] = [[]]
    private var fftBinFreq : [Float] = []
    private var sampleRate : Double = 44100.0
    let bufferSize = 1024
    var halfbufferSize = 256
    private var outerInnerFrequencyPercentages: [[Int : Float]] = []
    init(audioFile: String) {
        audio = Audio(music: audioFile, frequencies: backFrequencies)!
        //audio.setEquailizerOptions(gains: [0, -3, -6, -9, -12, -15, -18, -21, -24, -27, -30])
        //audio.setEquailizerOptions(gains: [0, -6, -12, -18, -24, -30, -36, -42, -48, -52, -58])
        settupFFTBinFrequencies()
        var testFreq = Float(110.0)
        while testFreq < fftBinFreq[fftBinFreq.count - 1]{
            logarithmicBinsFreq.append(testFreq)
            testFreq *= pow(2, 3/12)
        }
        linearToLogarithmicBins = Array(repeating: [], count: logarithmicBinsFreq.count)
        for i in 0..<(fftBinFreq.count) {
            var closestBin = 0
            var closestDst = Float(-1.0)
            for j in 0..<(logarithmicBinsFreq.count){
                let dst = abs(fftBinFreq[i] - logarithmicBinsFreq[j])
                if(dst < closestDst) || (closestDst == -1){
                    closestDst = dst
                    closestBin = j
                }
            }
            if closestDst != -1{
                linearToLogarithmicBins[closestBin].append(i)
            }
        }
        outerInnerFrequencyPercentages = Array(repeating: [:], count: backFrequencies.count)
        for i in 0..<(backFrequencies.count){
            var start = -1
            for j in 0..<(frequencies.count){
                if(backFrequencies[i] >= frequencies[j]){
                    start = j
                }
            }
            if(start == -1){
                outerInnerFrequencyPercentages[i][0] = 1
            } else if(start + 1 == frequencies.count){
                outerInnerFrequencyPercentages[i][frequencies.count - 1] = 1
            } else{   //in between inner frequencies
                let distanceAbove = backFrequencies[i] - frequencies[start]
                let distanceBetween = frequencies[start + 1] - frequencies[start]
                let perToUpper = Float(distanceAbove) / Float(distanceBetween)
                
                outerInnerFrequencyPercentages[i][start] = 1 - perToUpper
                outerInnerFrequencyPercentages[i][start + 1] = perToUpper
            }
        }
    }
    private func settupFFTBinFrequencies(){
        fftBinFreq = Array(repeating: Float(0.0), count: halfbufferSize)
        let offset = Float(sampleRate / Double(bufferSize))
        for i in 0..<(halfbufferSize){
            fftBinFreq[i] = Float(i) * offset
        }
    }
    public func PlayPause(play: Bool){
        if(play){
            audio.play()
        }else{
            audio.pause()
        }
    }
    public func outWave() -> [Float]{
        return audio.waveMag
    }
    public func outFFTMag() -> [Float]{
        return audio.fftMag// fftToVisual(data: audio.fftMag)
    }
    private func fftToVisual(data : [Float]) -> [Float]{
        var visual = Array(repeating: Float(0.0), count: logarithmicBinsFreq.count)
        if(data.count == 0){
            return visual
        }
        for i in 0..<(logarithmicBinsFreq.count){
            for j in 0..<(linearToLogarithmicBins[i].count){
                visual[i] += data[linearToLogarithmicBins[i][j]]
            }
            visual[i] /= Float(linearToLogarithmicBins[i].count)
        }
        return visual
    }
    private func updateFreqEQValues(freqEQ: [Float]) async {
        await audio.setEquailizerOptions(gains: freqEQ)
    }
    public func gainChanged(gain : Float){
        audio.setGain(gain: gain)
    }
    public func SpreadEQFromValues(innerFreqEQ : [Float]) async {
        freqEQOuter = Array(repeating: Float(0.0), count: backFrequencies.count)
        for i in 0..<(outerInnerFrequencyPercentages.count){
            for (index, percentage) in outerInnerFrequencyPercentages[i] {
                freqEQOuter[i] += innerFreqEQ[index] * percentage
            }
        } 
        await updateFreqEQValues(freqEQ: freqEQOuter)
    }
    public func changeAudioFile(audioFile: String, currentlyPlaying: Bool){
        audio.stop()
        audio.end()
        audio = Audio.init(music: audioFile, frequencies: backFrequencies)!
        if(currentlyPlaying){
            audio.play()
        }
    }
}
