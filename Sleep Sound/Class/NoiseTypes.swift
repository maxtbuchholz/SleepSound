//
//  NoiseTypes.swift
//  Sleep Sound
//
//  Created by Max Buchholz on 4/15/24.
//

import Foundation
class NoiseTypes{
    typealias FloatFunc = ([Int]) -> [Float]
    public var Types : [String : FloatFunc] = [:]
    public var Gains : [String : Float] = [:]
    init() {
        self.Types["white"] = whiteNoise
        self.Types["pink"] = pinkNoise
        self.Types["green"] = greenNoise
        self.Types["brown"] = brownNoise
        self.Types["blue"] = blueNoise
        self.Types["violet"] = violetNoise
        
        self.Gains["white"] = 0
        self.Gains["pink"] = 15
        self.Gains["green"] = 15
        self.Gains["brown"] = 30
        self.Gains["blue"] = 5
        self.Gains["violet"] = 10
    }
    private func whiteNoise(values: [Int]) ->[Float]{
        var noiseDB = Array(repeating: Float(0.0), count: values.count)
        return noiseDB
    }
    private func pinkNoise(values: [Int]) ->[Float]{
        var noiseDB = Array(repeating: Float(0.0), count: values.count)
        let initial = Float(values[0])
        for i in 0..<(noiseDB.count){
            let octDiff = log(Float(values[i]) / initial) / log(Float(2))
            noiseDB[i] = octDiff * -3
        }
        return noiseDB
    }
    private func greenNoise(values: [Int]) ->[Float]{
        var noiseDB = Array(repeating: Float(0.0), count: values.count)
        let initial = Float(values[0])
        for i in 0..<(noiseDB.count){
            let octDiff = abs(log(Float(values[i]) / 500) / log(Float(2)))
            noiseDB[i] = octDiff * -5
        }
        return noiseDB
    }
    private func brownNoise(values: [Int]) ->[Float]{
        var noiseDB = Array(repeating: Float(0.0), count: values.count)
        let initial = Float(values[0])
        for i in 0..<(noiseDB.count){
            let octDiff = log(Float(values[i]) / initial) / log(Float(2))
            noiseDB[i] = octDiff * -6
        }
        return noiseDB
    }
    private func blueNoise(values: [Int]) ->[Float]{
        var noiseDB = Array(repeating: Float(0.0), count: values.count)
        let initial = Float(values[values.count - 1])
        for i in 0..<(values.count){
            let octDiff = log(Float(initial / Float(values[i]))) / log(Float(2))
            noiseDB[i] = octDiff * -3
        }
        return noiseDB
    }
    private func violetNoise(values: [Int]) ->[Float]{
        var noiseDB = Array(repeating: Float(0.0), count: values.count)
        let initial = Float(values[values.count - 1])
        for i in 0..<(values.count){
            let octDiff = log(Float(initial / Float(values[i]))) / log(Float(2))
            noiseDB[i] = octDiff * -6.02
        }
        return noiseDB
    }
}
