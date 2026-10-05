import SwiftUI

// the result of checking one payslip against the shifts the student logged
struct PayslipReviewView: View {
    let environment: AppEnvironment
    let row: PayslipsViewModel.Row

    var body: some View {
        List {
            if let review = row.review {
                Section {
                    verdictHeader(review)
                }

                Section("Hours") {
                    line("You logged as worked", "\(HoursFormat.string(review.hoursRecorded)) h")
                    line("The payslip paid for", "\(HoursFormat.string(review.payslip.hoursPaid)) h")
                    if review.hoursGap > 0 {
                        Text("The payslip counts \(HoursFormat.string(review.hoursGap)) fewer hours than you recorded.")
                            .font(.footnote).foregroundStyle(.red)
                    }
                }

                Section("Pay") {
                    line("You should have been paid", HoursFormat.money(review.expectedPay))
                    line("You were paid", HoursFormat.money(review.payslip.amountPaid))
                }

                if case .underpaid = review.verdict {
                    Section("What you can do") {
                        Text("Show your shift log to your manager and ask them to check the hours. If it isn't fixed, the Fair Work Ombudsman can help — contacting them is free, including for visa holders.")
                            .font(.footnote)
                    }
                }
            } else if let problem = row.reviewProblem {
                Section {
                    Label(problem, systemImage: "questionmark.circle").foregroundStyle(.secondary)
                }
            }

            if let name = row.payslip.attachmentFileName,
               let url = environment.inbox.libraryURL(forFileNamed: name) {
                Section("Saved copy") {
                    ShareLink(item: url) { Label("View / share the payslip file", systemImage: "doc.fill") }
                }
            }
        }
        .navigationTitle(row.workplaceName)
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func verdictHeader(_ review: PayslipReview) -> some View {
        switch review.verdict {
        case .paidCorrectly:
            Label("Paid correctly", systemImage: "checkmark.seal.fill")
                .font(.title3.bold()).foregroundStyle(.green)
        case .underpaid(let shortfall):
            VStack(alignment: .leading, spacing: 4) {
                Label("Underpaid", systemImage: "exclamationmark.triangle.fill")
                    .font(.title3.bold()).foregroundStyle(.red)
                Text("You're short \(HoursFormat.money(shortfall)) for this period.")
            }
        case .overpaid(let excess):
            VStack(alignment: .leading, spacing: 4) {
                Label("Paid more than your log", systemImage: "arrow.up.circle.fill")
                    .font(.title3.bold()).foregroundStyle(.orange)
                Text("The payslip is \(HoursFormat.money(excess)) above what your shifts add up to. Check you've logged every shift.")
            }
        }
    }

    private func line(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value).bold()
        }
    }
}
