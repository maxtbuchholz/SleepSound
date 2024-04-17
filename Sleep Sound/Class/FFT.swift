//
//  FFT.swift
//  Sleep Sound
//
//  Created by Max Buchholz on 4/13/24.
//

import Foundation
import Accelerate
class FFT{
    static func toFloatArray(dArray: [Double]) -> [Float]{
        var fArray = Array(repeating: Float(0.0), count: dArray.count)
        for i in 0..<(fArray.count){
            fArray[i] = Float(dArray[i])
        }
        return fArray
    }
    static func sqrt(_ x: [Double]) -> [Double] {
        var results = [Double](repeating: 0.0, count: x.count)
        vvsqrt(&results, x, [Int32(x.count)])

        return results
    }
    static var boh = Float(0.00000000001)
    static func vfft(data: UnsafeMutablePointer<Float>, setup: OpaquePointer) -> [Float]{
        let bufferSize = 512
        let barAmount = 30
        var realIn = [Float](repeating: 0, count: bufferSize)
        var imagIn = [Float](repeating: 0, count: bufferSize)
        var realOut = [Float](repeating: 0, count: bufferSize)
        var imagOut = [Float](repeating: 0, count: bufferSize)
        for i in 0..<(bufferSize){
            realIn[i] = data[i]
        }
        vDSP_DFT_Execute(setup, &realIn, &imagIn, &realOut, &imagOut)
        var magnitudes = [Float](repeating: 0, count: barAmount)
        realOut.withUnsafeMutableBufferPointer { realBP in
            imagOut.withUnsafeMutableBufferPointer{ imagBP in
                var complex = DSPSplitComplex(realp: realBP.baseAddress!, imagp: imagBP.baseAddress!)
                vDSP_zvabs(&complex, 1, &magnitudes, 1, UInt(barAmount))
            }
        }
        var normalizedMagnitudes = [Float](repeating: 0, count: barAmount)
        var scalingFactor = Float(1)
        vDSP_vsmul(&magnitudes, 1, &scalingFactor, &normalizedMagnitudes, 1, UInt(barAmount))
        for i in 0..<(magnitudes.count){
            magnitudes[i] = 10 * log(magnitudes[i] / boh)
            magnitudes[i] -= 256
            if(magnitudes[i] < 0){
                magnitudes[i] = 0
            }
            magnitudes[i] = pow(magnitudes[i], 0.5)
        }
        return magnitudes
    }
}
