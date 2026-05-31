import Foundation

enum DemoDataFactory {
    static func makeData() -> AppData {
        AppData(
            workExperiences: makeWorkExperiences(),
            interviewOpportunities: makeInterviewOpportunities(),
            documents: makeDocuments(),
            lastBackupDate: nil,
            lastBackupPath: nil
        )
    }

    private static func makeWorkExperiences() -> [WorkExperience] {
        [
            WorkExperience(
                company: "Acme Systems",
                designation: "Senior Software Engineer",
                role: "macOS Platform Engineer",
                projectProduct: "Internal Analytics",
                team: "Platform",
                feature: "Performance dashboard",
                task: "Reduced dashboard load time",
                tags: "Performance Improvement, High Impact, Cross-team Work",
                date: daysAgo(2),
                situation: "Weekly reporting users were waiting too long for the dashboard to become usable.",
                action: "Profiled the load path, removed over-fetching, added pagination, and cached stable summary data.",
                outcome: "Cut initial load time from 5.8s to 2.1s for weekly reporting users.",
                challenges: "Slow API calls and over-fetching made the UI feel unreliable during peak usage.",
                skillsUsed: "Instruments, async loading, caching, API pagination",
                learning: "Profiling before refactoring kept the fix focused and measurable."
            ),
            WorkExperience(
                company: "Acme Systems",
                designation: "Software Engineer",
                role: "Developer Experience Engineer",
                projectProduct: "Release Tools",
                team: "Platform",
                feature: "Pre-release validation",
                task: "Built release checklist automation",
                tags: "Automation, Process Improvement, High Impact",
                date: daysAgo(6),
                situation: "Release readiness checks were spread across docs, chat, and manual memory.",
                action: "Built a lightweight checklist validator for release owners and connected it to CI checks.",
                outcome: "Reduced missed release steps and gave the team one source of truth before handoff.",
                challenges: "Checklist ownership was spread across docs, chat, and manual memory.",
                skillsUsed: "Shell scripting, JSON validation, CI checks",
                learning: "A small operational tool can remove repeated coordination cost."
            ),
            WorkExperience(
                company: "Acme Systems",
                designation: "Software Engineer",
                role: "Product Engineer",
                projectProduct: "Customer Portal",
                team: "Product Engineering",
                feature: "New engineer onboarding",
                task: "Documented onboarding flow",
                tags: "Documentation, Team Enablement",
                date: daysAgo(12),
                situation: "New engineers had to piece together setup steps from multiple sources.",
                action: "Mapped the onboarding flow, validated it with a new joiner, and documented ownership boundaries.",
                outcome: "Shortened setup questions during onboarding and clarified ownership boundaries.",
                challenges: "Existing docs were accurate individually but hard to follow end-to-end.",
                skillsUsed: "Technical writing, architecture review",
                learning: "Docs are more useful when they mirror the actual user journey."
            ),
            WorkExperience(
                company: "Acme Systems",
                designation: "Senior Software Engineer",
                role: "Backend Platform Engineer",
                projectProduct: "Billing Platform",
                team: "Payments",
                feature: "Invoice reconciliation",
                task: "Fixed duplicate invoice reconciliation",
                tags: "Bug Fix, Customer Impact, Incident / Production Issue",
                date: daysAgo(18),
                situation: "A small set of enterprise customers saw duplicate reconciliation rows after a retry path was triggered.",
                action: "Traced idempotency gaps, added reconciliation guards, backfilled affected rows, and documented the retry behavior.",
                outcome: "Stopped duplicate rows and reduced support escalation risk for billing operations.",
                challenges: "The issue reproduced only when retries overlapped with a delayed webhook.",
                skillsUsed: "PostgreSQL, idempotency, event debugging, production support",
                learning: "Retry logic needs explicit ownership of idempotency boundaries."
            ),
            WorkExperience(
                company: "Acme Systems",
                designation: "Senior Software Engineer",
                role: "Platform Engineer",
                projectProduct: "Search Service",
                team: "Core Platform",
                feature: "Index rebuild",
                task: "Delayed search index rollout",
                tags: "Delay / Blocker, Technical Debt, Learning / Upskilling",
                date: daysAgo(24),
                situation: "The new index pipeline passed functional tests but failed under a larger production-like data set.",
                action: "Paused rollout, profiled memory usage, split the rebuild into batches, and reset delivery expectations with stakeholders.",
                outcome: "Delivery moved by one sprint, but the final rollout avoided production instability.",
                challenges: "Initial estimates missed data-volume behavior and rebuild memory pressure.",
                skillsUsed: "Capacity testing, profiling, stakeholder communication",
                learning: "Large-data validation should happen before committing rollout dates."
            ),
            WorkExperience(
                company: "Acme Systems",
                designation: "Lead Software Engineer",
                role: "API Owner",
                projectProduct: "Partner Integrations",
                team: "Integrations",
                feature: "Contract cleanup",
                task: "Led API contract cleanup",
                tags: "Leadership, Cross-team Work, Process Improvement",
                date: daysAgo(31),
                situation: "Partner teams had inconsistent field naming and unclear validation ownership across three integration APIs.",
                action: "Ran a contract review, aligned schema owners, deprecated duplicate fields, and created a migration checklist.",
                outcome: "Reduced integration questions and made future API changes easier to review.",
                challenges: "Different teams had already built assumptions around inconsistent contract behavior.",
                skillsUsed: "API design, facilitation, migration planning",
                learning: "Clean contracts need explicit ownership as much as technical correctness."
            ),
            WorkExperience(
                company: "Acme Systems",
                designation: "Software Engineer",
                role: "macOS Platform Engineer",
                projectProduct: "Desktop Console",
                team: "Client Platform",
                feature: "Settings persistence",
                task: "Migrated settings storage",
                tags: "Architecture / Design, Technical Debt, Performance Improvement",
                date: daysAgo(39),
                situation: "Settings were stored in multiple local files, which made sync and debugging harder.",
                action: "Moved settings to one typed persistence layer, added migration coverage, and removed stale file reads.",
                outcome: "Reduced startup reads and made settings behavior easier to test.",
                challenges: "Backward compatibility required careful handling of older local data shapes.",
                skillsUsed: "Swift, Codable, migration testing, local persistence",
                learning: "A small persistence abstraction can remove a lot of incidental complexity."
            ),
            WorkExperience(
                company: "Acme Systems",
                designation: "Software Engineer",
                role: "Team Contributor",
                projectProduct: "Customer Portal",
                team: "Product Engineering",
                feature: "Team onboarding",
                task: "Mentored new engineer on feature delivery",
                tags: "Mentoring, Team Enablement, Documentation",
                date: daysAgo(46),
                situation: "A new engineer joined during an active delivery cycle and needed context on product flows and code ownership.",
                action: "Paired on the first feature, explained ownership boundaries, and created a concise delivery checklist.",
                outcome: "The engineer shipped their first change with fewer review cycles and clearer product context.",
                challenges: "Mentoring had to fit around ongoing sprint commitments.",
                skillsUsed: "Mentoring, code review, product context sharing",
                learning: "Short pairing sessions are more effective when paired with a written checklist."
            )
        ]
    }

    private static func makeInterviewOpportunities() -> [InterviewOpportunity] {
        [
            InterviewOpportunity(
                company: "Northstar Labs",
                role: "Senior macOS Engineer",
                source: "LinkedIn",
                applicationLink: "https://www.linkedin.com/jobs/view/northstar-labs-senior-macos-engineer",
                status: .interviewing,
                stage: "L2 technical",
                appliedDate: daysAgo(18),
                lastActivityDate: daysAgo(1),
                nextAction: "Prepare concurrency and SwiftUI table examples",
                nextActionDueDate: daysFromNow(1),
                hasReferral: true,
                referralChannel: "LinkedIn",
                referralProfileName: "Aarav Mehta",
                referralEmail: "aarav.mehta@example.com",
                referralStatus: "Submitted",
                referralNotes: "Asked for resume variant focused on native macOS work.",
                cooldownPeriodDays: nil,
                cooldownUntil: nil,
                techStack: "Swift, SwiftUI, AppKit, Combine, SQLite",
                jobDescription: "Own native macOS features for an analytics product, improve table-heavy workflows, and collaborate with product teams on performance-sensitive UI.",
                contactOrInterviewer: "Priya S.",
                pocEmail: "priya.s@northstar.example",
                pocNumber: "+91 98765 43210",
                interviewRounds: [
                    InterviewRound(
                        date: daysAgo(4),
                        roundName: "Recruiter screen",
                        interviewer: "Maya R.",
                        result: "Advanced",
                        feedback: "Strong product sense; asked to prepare deeper macOS examples."
                    ),
                    InterviewRound(
                        date: daysAgo(1),
                        roundName: "L1 technical",
                        interviewer: "Daniel K.",
                        result: "Advanced",
                        feedback: "Good Swift fundamentals; next round will focus on architecture."
                    )
                ],
                notes: "Use Work Experience examples on performance dashboard and release automation."
            ),
            InterviewOpportunity(
                company: "Cloudlane",
                role: "Backend Platform Engineer",
                source: "Naukri",
                applicationLink: "https://www.naukri.com/job-listings-backend-platform-engineer-cloudlane",
                status: .waiting,
                stage: "Take-home submitted",
                appliedDate: daysAgo(9),
                lastActivityDate: daysAgo(3),
                nextAction: "Follow up on take-home feedback",
                nextActionDueDate: daysFromNow(2),
                hasReferral: false,
                referralStatus: "Not Applicable",
                cooldownPeriodDays: nil,
                cooldownUntil: nil,
                techStack: "Go, Kubernetes, PostgreSQL, distributed systems",
                jobDescription: "Build platform APIs and internal services for distributed infrastructure teams, with focus on reliability and operational tooling.",
                contactOrInterviewer: "careers@cloudlane.example",
                pocEmail: "careers@cloudlane.example",
                pocNumber: "+91 99887 76655",
                interviewRounds: [
                    InterviewRound(
                        date: daysAgo(3),
                        roundName: "Take-home",
                        interviewer: "Platform team",
                        result: "Submitted",
                        feedback: "Pending review."
                    )
                ],
                notes: "Track whether they value product-facing backend work."
            ),
            InterviewOpportunity(
                company: "FinGrid",
                role: "iOS/macOS Engineer",
                source: "Referral",
                applicationLink: "https://jobs.lever.co/fingrid/ios-macos-engineer",
                status: .rejected,
                stage: "Closed",
                appliedDate: daysAgo(95),
                lastActivityDate: daysAgo(70),
                nextAction: "Eligible to apply again",
                nextActionDueDate: daysFromNow(0),
                hasReferral: true,
                referralChannel: "Former coworker",
                referralProfileName: "Neha Kapoor",
                referralEmail: "neha.kapoor@example.com",
                referralStatus: "Accepted",
                referralNotes: "Reach out before reapplying with updated resume.",
                cooldownPeriodDays: 65,
                cooldownUntil: nil,
                techStack: "Swift, UIKit, SwiftUI, Core Data",
                jobDescription: "Develop regulated financial mobile and desktop workflows with strong data handling, accessibility, and release quality expectations.",
                contactOrInterviewer: "Rohan P.",
                pocEmail: "rohan.p@fingrid.example",
                pocNumber: "+91 90909 11223",
                interviewRounds: [
                    InterviewRound(
                        date: daysAgo(75),
                        roundName: "Final",
                        interviewer: "Engineering manager",
                        result: "Rejected",
                        feedback: "Wanted more examples around regulated financial systems."
                    )
                ],
                notes: "Now appears in Eligible Again because cooldown is complete."
            ),
            InterviewOpportunity(
                company: "DesignOps Studio",
                role: "Tools Engineer",
                source: "Cutshort",
                applicationLink: "https://cutshort.io/job/tools-engineer-designops-studio",
                status: .applied,
                stage: "Applied",
                appliedDate: daysAgo(1),
                lastActivityDate: daysAgo(1),
                nextAction: "Find referral PoC",
                nextActionDueDate: daysFromNow(3),
                hasReferral: false,
                referralStatus: "To Ask",
                cooldownPeriodDays: nil,
                cooldownUntil: nil,
                techStack: "Swift, TypeScript, Figma plugins",
                jobDescription: "Build internal tools and design-system automation across native apps, web tooling, and Figma plugin workflows.",
                contactOrInterviewer: "",
                pocEmail: "",
                pocNumber: "",
                interviewRounds: [],
                notes: "Potential fit for developer tooling and design-system work."
            ),
            InterviewOpportunity(
                company: "BrightBank",
                role: "Senior Product Engineer",
                source: "Careers Page",
                applicationLink: "https://brightbank.example/careers/senior-product-engineer",
                status: .invited,
                stage: "",
                appliedDate: daysAgo(5),
                lastActivityDate: daysAgo(1),
                nextAction: "Share availability and confirm first round",
                nextActionDueDate: daysFromNow(1),
                hasReferral: true,
                referralChannel: "Alumni network",
                referralProfileName: "Ishaan Rao",
                referralEmail: "ishaan.rao@example.com",
                referralStatus: "Requested",
                referralNotes: "Asked for context on engineering manager expectations.",
                cooldownPeriodDays: nil,
                cooldownUntil: nil,
                techStack: "Swift, Kotlin, GraphQL, product analytics",
                jobDescription: "Build user-facing financial workflows and partner with product managers on growth and reliability improvements.",
                contactOrInterviewer: "Hiring team",
                pocEmail: "talent@brightbank.example",
                pocNumber: "+91 91234 56789",
                interviewRounds: [],
                notes: "Good role for product engineering examples from Customer Portal."
            ),
            InterviewOpportunity(
                company: "StackRoute",
                role: "Platform Reliability Engineer",
                source: "Instahyre",
                applicationLink: "https://www.instahyre.com/job/platform-reliability-engineer-stackroute",
                status: .interviewing,
                stage: "",
                appliedDate: daysAgo(21),
                lastActivityDate: daysAgo(2),
                nextAction: "Prepare incident and capacity planning stories",
                nextActionDueDate: daysFromNow(2),
                hasReferral: false,
                referralStatus: "Not Applicable",
                cooldownPeriodDays: nil,
                cooldownUntil: nil,
                techStack: "Go, AWS, Kubernetes, observability",
                jobDescription: "Improve platform reliability, incident response, and deployment confidence across internal services.",
                contactOrInterviewer: "DevOps panel",
                pocEmail: "recruiting@stackroute.example",
                pocNumber: "+91 93456 77880",
                interviewRounds: [
                    InterviewRound(
                        date: daysAgo(7),
                        roundName: "Recruiter screen",
                        interviewer: "Kavya N.",
                        result: "Advanced",
                        feedback: "Asked for stronger examples around incident ownership."
                    ),
                    InterviewRound(
                        date: daysAgo(2),
                        roundName: "Technical deep dive",
                        interviewer: "Reliability panel",
                        result: "Pending",
                        feedback: "Discussed production issue and release automation examples."
                    )
                ],
                notes: "Use duplicate invoice incident and release checklist automation examples."
            ),
            InterviewOpportunity(
                company: "NovaApps",
                role: "macOS Developer",
                source: "Hirist",
                applicationLink: "https://www.hirist.com/job/macos-developer-novaapps",
                status: .withdrawn,
                stage: "",
                appliedDate: daysAgo(55),
                lastActivityDate: daysAgo(35),
                nextAction: "",
                nextActionDueDate: nil,
                hasReferral: false,
                referralStatus: "Not Applicable",
                cooldownPeriodDays: 90,
                cooldownUntil: nil,
                techStack: "SwiftUI, AppKit, Core Data",
                jobDescription: "Maintain an existing macOS productivity app and modernize selected AppKit workflows.",
                contactOrInterviewer: "Recruiter desk",
                pocEmail: "jobs@novaapps.example",
                pocNumber: "+91 92345 99881",
                interviewRounds: [
                    InterviewRound(
                        date: daysAgo(35),
                        roundName: "Recruiter screen",
                        interviewer: "External recruiter",
                        result: "Withdrawn",
                        feedback: "Role scope was mostly maintenance and did not match current goals."
                    )
                ],
                notes: "Closed but not yet re-eligible."
            ),
            InterviewOpportunity(
                company: "Mercury Cloud",
                role: "Backend Engineer",
                source: "Wellfound",
                applicationLink: "https://wellfound.com/jobs/mercury-cloud-backend-engineer",
                status: .closed,
                stage: "",
                appliedDate: daysAgo(130),
                lastActivityDate: daysAgo(100),
                nextAction: "Eligible to retry with platform resume",
                nextActionDueDate: nil,
                hasReferral: true,
                referralChannel: "Community Slack",
                referralProfileName: "Sana Malik",
                referralEmail: "sana.malik@example.com",
                referralStatus: "Accepted",
                referralNotes: "Reach out with backend-focused resume before reapplying.",
                cooldownPeriodDays: 90,
                cooldownUntil: nil,
                techStack: "Java, Kafka, PostgreSQL, distributed systems",
                jobDescription: "Build event-driven services for cloud billing and usage analytics.",
                contactOrInterviewer: "Engineering manager",
                pocEmail: "eng-hiring@mercurycloud.example",
                pocNumber: "+91 90000 44556",
                interviewRounds: [
                    InterviewRound(
                        date: daysAgo(100),
                        roundName: "System design",
                        interviewer: "Engineering manager",
                        result: "Rejected",
                        feedback: "Needed deeper tradeoff discussion for event replay and data repair."
                    )
                ],
                notes: "Should appear in Eligible Again because cooldown has completed."
            )
        ]
    }

    private static func makeDocuments() -> [DocumentRecord] {
        [
            DocumentRecord(
                name: "Backend Resume 2026",
                kind: .resume,
                version: "2026.05",
                company: "",
                notes: "Demo resume document for testing document metadata.",
                originalFileName: "Backend_Resume_2026.pdf",
                storedFileName: "demo-backend-resume.pdf"
            ),
            DocumentRecord(
                name: "Offer Letter Example",
                kind: .offerLetter,
                version: "Demo",
                company: "Example Corp",
                notes: "Demo offer letter placeholder.",
                originalFileName: "Offer_Letter_Example.pdf",
                storedFileName: "demo-offer-letter.pdf"
            ),
            DocumentRecord(
                name: "Experience Letter Example",
                kind: .experienceLetter,
                version: "Demo",
                company: "Previous Company",
                notes: "Demo experience letter placeholder.",
                originalFileName: "Experience_Letter_Example.pdf",
                storedFileName: "demo-experience-letter.pdf"
            ),
            DocumentRecord(
                name: "Relieving Letter Example",
                kind: .relievingLetter,
                version: "Demo",
                company: "Previous Company",
                notes: "Demo relieving letter placeholder.",
                originalFileName: "Relieving_Letter_Example.pdf",
                storedFileName: "demo-relieving-letter.pdf"
            ),
            DocumentRecord(
                name: "Cloud Platform Certificate",
                kind: .certificate,
                version: "Demo",
                company: "",
                notes: "Demo certificate document for testing document search and metadata.",
                originalFileName: "Cloud_Platform_Certificate.pdf",
                storedFileName: "demo-cloud-platform-certificate.pdf"
            )
        ]
    }

    static func demoDocumentText(for fileName: String) -> (title: String, body: String)? {
        switch fileName {
        case "demo-backend-resume.pdf":
            ("Backend Resume Demo", "This placeholder PDF lets you test document storage, metadata editing, open, and reveal actions.")
        case "demo-offer-letter.pdf":
            ("Offer Letter Demo", "This placeholder PDF represents an important career document stored in the Work Log document vault.")
        case "demo-experience-letter.pdf":
            ("Experience Letter Demo", "This placeholder PDF represents experience or relieving documentation for testing the Documents feature.")
        case "demo-relieving-letter.pdf":
            ("Relieving Letter Demo", "This placeholder PDF represents a relieving letter stored in the Work Log document vault.")
        case "demo-cloud-platform-certificate.pdf":
            ("Cloud Platform Certificate Demo", "This placeholder PDF represents a professional certificate stored with searchable metadata.")
        default:
            nil
        }
    }

    private static func daysAgo(_ days: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
    }

    private static func daysFromNow(_ days: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: days, to: Date()) ?? Date()
    }
}
