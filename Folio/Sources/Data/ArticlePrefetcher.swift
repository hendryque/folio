import Foundation
import SwiftData
import CoreGraphics

/// Warms everything a Today-tile tap needs: mobile-html into the SwiftData
/// cache, plus the face-aware focal point and hero URL onto the cache row.
/// A prefetched article mounts its full WebView render immediately on tap
/// instead of sitting on the text preview through several round trips.
@MainActor
enum ArticlePrefetcher {
    /// Serial and low-priority on purpose: this is opportunistic warming on a
    /// possibly-cellular connection, not a download manager.
    static func prefetch(_ articles: [ArticleSummary], language: String, context: ModelContext) {
        Task(priority: .utility) {
            for article in articles {
                await prefetchOne(article, language: language, context: context)
            }
        }
    }

    private static func prefetchOne(_ article: ArticleSummary, language: String, context: ModelContext) async {
        let title = article.title
        if let cached = CachedArticle.fetch(title: title, language: language, in: context), cached.isFresh {
            // HTML is current; just backfill focal/hero if an older row lacks them.
            if cached.focalPoint == nil,
               let focal = await FocalPointDetector.shared.resolvedFocalPoint(for: article) {
                cached.focalPointX = focal.x
                cached.focalPointY = focal.y
            }
            if cached.heroImageURL == nil {
                cached.heroImageURL = article.imageURL(width: ThumbnailWidth.hero)
            }
            try? context.save()
            return
        }

        guard let html = try? await WikipediaClient.shared.mobileHTML(title: title, language: language) else {
            return
        }
        let focal = await FocalPointDetector.shared.resolvedFocalPoint(for: article)
        CachedArticle.upsert(
            title: title,
            language: language,
            html: html,
            focalPoint: focal,
            heroImageURL: article.imageURL(width: ThumbnailWidth.hero),
            in: context
        )
    }

}
