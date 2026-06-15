import SwiftUI
import SwiftData
import MapKit
import CoreLocation
import UIKit

struct NearbyView: View {
    @Query private var settingsList: [AppSettings]
    @State private var locationProvider = LocationProvider()
    @State private var articles: [NearbyArticle] = []
    @State private var selectedID: Int?
    @State private var isLoading = false
    @State private var loadError: String?
    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var lastQueryCoord: CLLocationCoordinate2D?
    @State private var lastQueryRadius: Int?
    @State private var didInitializeCamera = false
    @State private var fetchTask: Task<Void, Never>?

    private var language: String { settingsList.first?.defaultLanguage ?? "en" }

    var body: some View {
        Group {
            switch locationProvider.authorization {
            case .notDetermined:
                LocationPermissionPrompt {
                    locationProvider.requestPermission()
                }
            case .denied, .restricted:
                LocationDenied()
            case .authorizedAlways, .authorizedWhenInUse:
                content
            @unknown default:
                Text("Location unavailable").foregroundStyle(.secondary)
            }
        }
        .onChange(of: locationProvider.coordinate?.latitude) { _, _ in
            handleCoordinateChange()
        }
        .onAppear { locationProvider.startUpdates() }
        .onDisappear {
            locationProvider.stopUpdates()
            fetchTask?.cancel()
        }
    }

    @ViewBuilder
    private var content: some View {
        if locationProvider.coordinate != nil {
            ZStack(alignment: .bottom) {
                Map(position: $cameraPosition, selection: $selectedID) {
                    UserAnnotation()
                    ForEach(articles) { article in
                        Marker(
                            article.title.replacingOccurrences(of: "_", with: " "),
                            systemImage: "book",
                            coordinate: CLLocationCoordinate2D(latitude: article.latitude, longitude: article.longitude)
                        )
                        .tag(article.id)
                        .tint(Color.accentColor)
                    }
                }
                .mapStyle(.standard(elevation: .flat))
                .mapControls {
                    MapCompass()
                    MapUserLocationButton()
                    MapScaleView()
                }
                .onMapCameraChange(frequency: .onEnd) { context in
                    guard didInitializeCamera else { return }
                    scheduleFetch(for: context.region)
                }

                if !articles.isEmpty {
                    NearbyCarousel(articles: articles, selectedID: $selectedID, language: language)
                        .frame(height: 110)
                        .padding(.bottom, 8)
                } else if isLoading {
                    ProgressView()
                        .padding()
                        .background(.thinMaterial, in: Capsule())
                        .padding(.bottom, 16)
                } else if let loadError {
                    Text(loadError)
                        .font(.footnote)
                        .padding(8)
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
                        .padding(.bottom, 16)
                }
            }
        } else {
            VStack(spacing: 12) {
                ProgressView()
                Text("Locating…")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func handleCoordinateChange() {
        guard let coord = locationProvider.coordinate else { return }
        guard !didInitializeCamera else { return }
        didInitializeCamera = true
        cameraPosition = .region(
            MKCoordinateRegion(
                center: coord,
                span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
            )
        )
    }

    /// Inscribed-circle radius of the visible region in meters, clamped to Wikipedia's
    /// 10 km gsradius ceiling.
    private func radiusMeters(for region: MKCoordinateRegion) -> Int {
        let latMeters = region.span.latitudeDelta * 111_000
        let lonMeters = region.span.longitudeDelta * 111_000 * cos(region.center.latitude * .pi / 180)
        let inscribed = min(latMeters, lonMeters) / 2
        return max(500, min(10_000, Int(inscribed)))
    }

    private func scheduleFetch(for region: MKCoordinateRegion) {
        let center = region.center
        let radius = radiusMeters(for: region)
        if let lastCoord = lastQueryCoord, let lastRadius = lastQueryRadius {
            let moved = distance(lastCoord, center)
            let zoomChange = abs(Double(radius - lastRadius)) / Double(lastRadius)
            if moved < 250, zoomChange < 0.3 { return }
        }
        fetchTask?.cancel()
        fetchTask = Task { @MainActor in
            await fetch(center: center, radius: radius)
        }
    }

    private func fetch(center: CLLocationCoordinate2D, radius: Int) async {
        isLoading = true
        defer { isLoading = false }
        loadError = nil
        do {
            let fresh = try await WikipediaClient.shared.nearby(
                latitude: center.latitude,
                longitude: center.longitude,
                language: language,
                radiusMeters: radius
            )
            if Task.isCancelled { return }
            articles = fresh
            selectedID = nil
            lastQueryCoord = center
            lastQueryRadius = radius
        } catch {
            if Task.isCancelled { return }
            loadError = error.localizedDescription
        }
    }

    private func distance(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D) -> CLLocationDistance {
        CLLocation(latitude: a.latitude, longitude: a.longitude)
            .distance(from: CLLocation(latitude: b.latitude, longitude: b.longitude))
    }
}

private struct LocationPermissionPrompt: View {
    let action: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "location.circle")
                .font(.system(size: 56))
                .foregroundStyle(.tint)
            Text("Discover Wikipedia near you")
                .font(.custom("EBGaramond-Regular", size: 24, relativeTo: .body))
                .multilineTextAlignment(.center)
            Text("Folio uses your location only to query Wikipedia's geosearch endpoint. Nothing is sent anywhere else.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button(action: action) {
                Text("Allow location")
                    .padding(.horizontal, 24)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

private struct LocationDenied: View {
    var body: some View {
        ContentUnavailableView {
            Label("Location is off", systemImage: "location.slash")
        } description: {
            Text("Enable location for Folio in iOS Settings to use Nearby.")
        } actions: {
            if let url = URL(string: UIApplication.openSettingsURLString) {
                Link("Open Settings", destination: url)
            }
        }
    }
}
