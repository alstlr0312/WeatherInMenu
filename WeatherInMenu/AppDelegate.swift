//
//  AppDelegate.swift
//  StatusBarTextApp
//
//  Created by 민식 on 4/12/25.
//
import Cocoa
import CoreLocation

@main
class AppDelegate: NSObject, NSApplicationDelegate, XMLParserDelegate, CLLocationManagerDelegate {

    var statusItem: NSStatusItem?
    var currentWeather: String = "🌤️ 로딩 중…"

    var locationManager: CLLocationManager?
    var latitude: Double?
    var longitude: Double?
    var currentAddress: String = "주소 불러오는 중..."

    @IBOutlet weak var window: NSWindow!

    var pcp = "-" // 강수량
    var pty = "-" // 강수형태
    var pop = "-" // 강수확률
    var tmp = "-" // 기온
    var sky = "-" // 하늘상태
    var reh = "-" // 습도
    var wsd = "-" // 풍속

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        setupStatusBar()
        requestLocation()
    }

    func applicationWillTerminate(_ aNotification: Notification) {}

    func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem?.button?.title = currentWeather

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "PCP (강수량): -", action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "PTY (강수형태): -", action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "POP (강수확률): -", action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "TMP (기온): -", action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "SKY (하늘상태): -", action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "REH (습도): -", action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "WSD (풍속): -", action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: currentAddress, action: nil, keyEquivalent: ""))
        statusItem?.menu = menu
    }

    func requestLocation() {
        locationManager = CLLocationManager()
        locationManager?.delegate = self
        locationManager?.desiredAccuracy = kCLLocationAccuracyHundredMeters
        locationManager?.requestWhenInUseAuthorization()
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.locationManager?.startUpdatingLocation()
            }
        case .denied, .restricted:
            currentWeather = "📍권한 없음"
            statusItem?.button?.title = currentWeather
        case .notDetermined:
            locationManager?.requestWhenInUseAuthorization()
        @unknown default: break
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        currentWeather = "📍위치 실패"
        statusItem?.button?.title = currentWeather
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.first else { return }

        latitude = location.coordinate.latitude
        longitude = location.coordinate.longitude
        let converter = LamcProjection()
        let grid = converter.convertToGrid(lat: latitude!, lon: longitude!)
        let nx = String(grid.nx)
        let ny = String(grid.ny)

        fetchWeather(nx: nx, ny: ny)
        fetchAddress(location: location)

        locationManager?.stopUpdatingLocation()
    }

    func fetchAddress(location: CLLocation) {
        CLGeocoder().reverseGeocodeLocation(location) { placemarks, _ in
            if let placemark = placemarks?.first {
                self.currentAddress = (placemark.locality ?? "") + " " + (placemark.thoroughfare ?? "")
            } else {
                self.currentAddress = "주소 불러오기 실패"
            }
            DispatchQueue.main.async {
                self.statusItem?.menu?.items.last?.title = self.currentAddress
            }
        }
    }

    func fetchWeather(nx: String, ny: String) {
        let endpoint = "http://apis.data.go.kr/1360000/VilageFcstInfoService_2.0/getVilageFcst"
        let serviceKey = "hhbQu5nRBusr5BlOIDF%2FRCLif3Jouo%2FXSivdbIpFKNmqRGpqAfYgVOifn8AVleQ5GLJrE0huwPY%2BmdGgprrWMQ%3D%3D"

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd"
        let baseDate = dateFormatter.string(from: Date())
        let baseTime = getBaseTime()

        let query = [
            "numOfRows": "15",
            "pageNo": "1",
            "dataType": "XML",
            "base_date": baseDate,
            "base_time": baseTime,
            "nx": nx,
            "ny": ny
        ].map { "\($0.key.urlEncoded())=\($0.value.urlEncoded())" }.joined(separator: "&")

        guard let url = URL(string: "\(endpoint)?serviceKey=\(serviceKey)&\(query)") else { return }

        URLSession.shared.dataTask(with: url) { data, _, _ in
            guard let data = data else { return }
            if let xmlString = String(data: data, encoding: .utf8) {
                   print("📄 수신된 XML 전체 데이터:\n\(xmlString)")
               }

            let parser = XMLParser(data: data)
            parser.delegate = self
            parser.parse()
        }.resume()
    }

    func getBaseTime() -> String {
        let now = Calendar.current.date(byAdding: .minute, value: -40, to: Date())!
        let hour = Calendar.current.component(.hour, from: now)
        let baseTimes = [2, 5, 8, 11, 14, 17, 20, 23]
        let closest = baseTimes.last { $0 <= hour } ?? 23
        return String(format: "%02d00", closest)
    }

    var currentElement = ""
    var currentCategory = ""
    var currentFcstTime = ""

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        currentElement = elementName
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        switch currentElement {
        case "category": currentCategory = trimmed
        case "fcstValue":
            switch currentCategory {
            case "PCP": pcp = trimmed
            case "PTY": pty = interpretPrecipitationType(trimmed)
            case "POP": pop = trimmed
            case "TMP", "T1H": tmp = trimmed
            case "SKY": sky = interpretSkyType(trimmed)
            case "REH": reh = trimmed
            case "WSD": wsd = trimmed
            default: break
            }
        default: break
        }
    }

    func parserDidEndDocument(_ parser: XMLParser) {
        DispatchQueue.main.async {
            self.currentWeather = self.tmp.isEmpty ? "⚠️ 데이터 없음" : "🌡️ \(self.tmp)°C"
            self.statusItem?.button?.title = self.currentWeather
            if let menu = self.statusItem?.menu {
                menu.items[0].title = "PCP (강수량): \(interpretPrecipitation(self.pcp))"
                menu.items[1].title = "PTY (강수형태): \(self.pty)"
                menu.items[2].title = "POP (강수확률): \(self.pop)%"
                menu.items[3].title = "TMP (기온): \(self.tmp)°C"
                menu.items[4].title = "SKY (하늘상태): \(self.sky)"
                menu.items[5].title = "REH (습도): \(self.reh)%"
                menu.items[6].title = "WSD (풍속): \(self.wsd) m/s"
            }
            // 날씨 이미지 설정
            let weatherImageName = selectWeatherImage(sky: self.sky, pty: self.pty)
            self.statusItem?.menu?.items.first?.image = NSImage(named: weatherImageName)
        }
    }
}

func interpretPrecipitation(_ value: String) -> String {
    if value == "강수없음" || value == "-" {
        return "강수 없음"
    }
    if let val = Double(value.replacingOccurrences(of: "mm", with: "")) {
        switch val {
        case ..<3: return "약한 비"
        case 3..<15: return "보통 비"
        default: return "강한 비"
        }
    }
    return value
}

func interpretPrecipitationType(_ value: String) -> String {
    switch value {
    case "0": return "없음"
    case "1": return "비"
    case "2": return "비/눈"
    case "3": return "눈"
    case "4": return "소나기"
    default: return value
    }
}

func interpretSkyType(_ value: String) -> String {
    switch value {
    case "1": return "맑음"
    case "3": return "구름 많음"
    case "4": return "흐림"
    default: return value
    }
}
func selectWeatherImage(sky: String, pty: String) -> String {
    if pty != "없음" {
        return "rainimg" // 강수 중이면 무조건 비 이미지
    }

    switch sky {
    case "맑음":
        return "sunimg"
    case "구름많음", "흐림":
        return "cloudimg"
    default:
        return "cloudimg"
    }
}


extension String {
    func urlEncoded() -> String {
        self.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? self
    }
}
