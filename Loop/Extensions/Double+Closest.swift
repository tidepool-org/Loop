//
//  Double+Closest.swift
//  Loop
//
//  Created by Cameron Ingham on 3/20/25.
//

extension Double {
    func findClosest(in numberSet: [Double]) -> Double {
        guard !numberSet.isEmpty else {
            return self
        }
        
        guard numberSet.count > 1 else {
            return numberSet[0]
        }
        
        return numberSet.reduce(numberSet[0]) { closest, current in
            let currentDifference = abs(current - self)
            let closestDifference = abs(closest - self)
            
            return currentDifference < closestDifference ? current : closest
        }
    }
}
