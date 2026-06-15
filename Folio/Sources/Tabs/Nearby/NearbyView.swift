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
        .onDisappear { locationProvider.stopUpdates() }
    }

    @ViewBuilder
    private var content: some View {
        if let coord = locationProvider.coordinate {
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
            .task(id: coordKey(coord)) {
                await fetchIfNeeded(near: coord)
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
        if lastQueryCoord == nil {
            cameraPosition = .region(
                MKCoordinateRegion(
                    center: coord,
                    span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                )
            )
        }
    }

    private func fetchIfNeeded(near coord: CLLocationCoordinate2D) async {
        if let last = lastQueryCoord, distance(last, coord) < 250 { return }
        await fetch(near: coord)
    }

    private func fetch(near coord: CLLocationCoordinate2D) async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        loadError = nil
        do {
            articles = try await WikipediaClient.shared.nearby(
                latitude: coord.latitude,
                longitude: coord.longitude,
                language: language
            )
            lastQueryCoord = coord
        } catch {
            loadError = error.localizedDescription
        }
    }

    private func distance(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D) -> CLLocationDistance {
        CLLocation(latitude: a.latitude, longitude: a.longitude)
            .distance(from: CLLocation(latitude: b.latitude, longitude: b.longitude))
    }

    private func coordKey(_ coord: CLLocationCoordinate2D) -> String {
        String(format: "%.3f,%.3f", coord.latitude, coord.longitude)
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
