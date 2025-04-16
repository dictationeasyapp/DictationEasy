import SwiftUI
import GoogleMobileAds

struct BannerAdView: UIViewControllerRepresentable {
    // Use the test ad unit ID for now
    private let adUnitID: String = "ca-app-pub-3940256099942544/2934735716"

    func makeUIViewController(context: Context) -> UIViewController {
        let viewController = UIViewController()
        let bannerView = BannerView(adSize: AdSizeBanner) // 320x50 banner size
        bannerView.adUnitID = adUnitID
        bannerView.rootViewController = viewController
        bannerView.delegate = context.coordinator

        // Configure the ad request based on ATT status
        let request = Request()
        if !AppDelegate.isTrackingAuthorized {
            // Use non-personalized ads if tracking is not authorized
            let extras = Extras()
            extras.additionalParameters = ["npa": "1"] // Non-personalized ads
            request.register(extras)
            print("BannerAdView: Requesting non-personalized ads (npa=1)")
        } else {
            print("BannerAdView: Requesting personalized ads")
        }
        bannerView.load(request)

        // Add the banner view to the view controller's view
        viewController.view.addSubview(bannerView)
        bannerView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            bannerView.centerXAnchor.constraint(equalTo: viewController.view.centerXAnchor),
            bannerView.bottomAnchor.constraint(equalTo: viewController.view.bottomAnchor)
        ])

        return viewController
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        // No updates needed for now
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject, BannerViewDelegate {
        func bannerViewDidReceiveAd(_ bannerView: BannerView) {
            print("BannerAdView: Banner ad received successfully")
        }

        func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: Error) {
            print("BannerAdView: Failed to receive banner ad with error: \(error.localizedDescription)")
        }
    }
}

#Preview {
    BannerAdView()
}
