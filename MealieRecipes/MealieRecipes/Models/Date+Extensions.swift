import Foundation

extension Calendar {
    func startOfWeek(for date: Date) -> Date {
        let components = self.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return self.date(from: components)!
    }
}

extension Date {
    func calendarWeekNumber(using calendar: Calendar = Calendar.current) -> Int {
        return calendar.component(.weekOfYear, from: self)
    }
}
