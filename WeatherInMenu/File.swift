//
//  File.swift
//  WeatherInMenu
//
//  Created by 민식 on 5/1/25.
//

import Foundation

class LamcProjection {
    // 격자 설정 상수
    let RE: Double = 6371.00877    // 지구 반경(km)
    let GRID: Double = 5.0         // 격자 간격 (km)
    let SLAT1: Double = 30.0       // 표준 위도1
    let SLAT2: Double = 60.0       // 표준 위도2
    let OLON: Double = 126.0       // 기준 경도
    let OLAT: Double = 38.0        // 기준 위도
    let XO: Double = 43.0          // 기준 X좌표
    let YO: Double = 136.0         // 기준 Y좌표

    let DEGRAD = Double.pi / 180.0
    let RADDEG = 180.0 / Double.pi

    private var re: Double = 0.0
    private var slat1: Double = 0.0
    private var slat2: Double = 0.0
    private var olon: Double = 0.0
    private var olat: Double = 0.0
    private var sn: Double = 0.0
    private var sf: Double = 0.0
    private var ro: Double = 0.0

    init() {
        re = RE / GRID
        slat1 = SLAT1 * DEGRAD
        slat2 = SLAT2 * DEGRAD
        olon = OLON * DEGRAD
        olat = OLAT * DEGRAD

        let tan1 = tan(Double.pi * 0.25 + slat1 * 0.5)
        let tan2 = tan(Double.pi * 0.25 + slat2 * 0.5)
        let log1 = log(cos(slat1) / tan1)
        let log2 = log(cos(slat2) / tan2)
        sn = log1 / log2

        let sfNumer = tan(Double.pi * 0.25 + slat1 * 0.5)
        sf = pow(sfNumer, sn) * cos(slat1) / sn

        let roNumer = tan(Double.pi * 0.25 + olat * 0.5)
        ro = re * sf / pow(roNumer, sn)
    }

    /// 위도, 경도 → 격자 좌표 (nx, ny)
    func convertToGrid(lat: Double, lon: Double) -> (nx: Int, ny: Int) {
        let ra = re * sf / pow(tan(Double.pi * 0.25 + (lat * DEGRAD) * 0.5), sn)
        var theta = lon * DEGRAD - olon
        if theta > Double.pi { theta -= 2.0 * Double.pi }
        if theta < -Double.pi { theta += 2.0 * Double.pi }
        theta *= sn

        let x = ra * sin(theta) + XO
        let y = ro - ra * cos(theta) + YO
        return (nx: Int(x.rounded()), ny: Int(y.rounded()))
    }

    /// 격자 좌표 (nx, ny) → 위도, 경도
    func convertToLatLon(nx: Int, ny: Int) -> (lat: Double, lon: Double) {
        let x = Double(nx) - XO
        let y = ro - (Double(ny) - YO)

        let ra = sqrt(x * x + y * y)
        var theta = atan2(x, y)
        if theta < 0.0 { theta += 2.0 * Double.pi }
        theta /= sn

        let alat = 2.0 * atan(pow(re * sf / ra, 1.0 / sn)) - Double.pi * 0.5
        let alon = theta + olon

        return (lat: alat * RADDEG, lon: alon * RADDEG)
    }
}

