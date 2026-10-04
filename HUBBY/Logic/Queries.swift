import Foundation

enum GmailQueries {
    static var threatScan: String {
        "in:inbox newer_than:7d (from:creditkarma.com OR from:kikoff.com OR from:usa.experian.com OR from:capitalone.com OR from:accounts.google.com OR subject:(\"collection account\" OR tradeline OR Declined OR \"Critical security alert\"))"
    }

    static var leadScan: String {
        "in:inbox newer_than:3d (from:match.indeed.com OR from:jobs-noreply@linkedin.com OR from:backstage.com)"
    }
}
