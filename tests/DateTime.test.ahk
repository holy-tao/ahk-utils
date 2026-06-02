#Requires AutoHotkey v2.0

#Include ./YUnit/Assert.ahk
#Include ../text/DateTime.ahk

class DateTimeTests {

    class Construction {
        Construct_AllFields() {
            dt := DateTime(2026, 5, 20, 14, 30, 45, 123, 0)
            Assert.Equals(dt.year, 2026)
            Assert.Equals(dt.month, 5)
            Assert.Equals(dt.day, 20)
            Assert.Equals(dt.hours, 14)
            Assert.Equals(dt.minutes, 30)
            Assert.Equals(dt.seconds, 45)
            Assert.Equals(dt.milliseconds, 123)
            Assert.Equals(dt.offsetMinutes, 0)
        }

        Construct_NoOffset_StoresEmptyString() {
            dt := DateTime(2026, 5, 20)
            Assert.Equals(dt.offsetMinutes, "")
        }

        Construct_InvalidMonthHigh_Throws() {
            Assert.Throws((*) => DateTime(2026, 13, 1), ValueError)
        }

        Construct_InvalidMonthLow_Throws() {
            Assert.Throws((*) => DateTime(2026, 0, 1), ValueError)
        }

        Construct_DayBeyondMonthLength_Throws() {
            ; April only has 30 days
            Assert.Throws((*) => DateTime(2026, 4, 31), ValueError)
        }

        Construct_FebInvalidLeapDay_Throws() {
            ; 2026 is not a leap year
            Assert.Throws((*) => DateTime(2026, 2, 29), ValueError)
        }

        Construct_FebValidLeapDay_OK() {
            dt := DateTime(2024, 2, 29)
            Assert.Equals(dt.day, 29)
        }

        Construct_YearTooLow_Throws() {
            Assert.Throws((*) => DateTime(-1, 1, 1), ValueError)
        }

        Construct_YearTooHigh_Throws() {
            Assert.Throws((*) => DateTime(10000, 1, 1), ValueError)
        }

        Construct_NonIntegerField_Throws() {
            Assert.Throws((*) => DateTime("abc", 1, 1), TypeError)
        }
    }

    class LeapYear {
        DivisibleBy4_True() {
            Assert.Equals(DateTime.IsLeapYear(2024), true)
        }

        NotDivisibleBy4_False() {
            Assert.Equals(DateTime.IsLeapYear(2026), false)
        }

        DivisibleBy100NotBy400_False() {
            Assert.Equals(DateTime.IsLeapYear(1900), false)
            Assert.Equals(DateTime.IsLeapYear(2100), false)
        }

        DivisibleBy400_True() {
            Assert.Equals(DateTime.IsLeapYear(2000), true)
            Assert.Equals(DateTime.IsLeapYear(2400), true)
        }

        Property_ReadsYear() {
            Assert.Equals(DateTime(2024, 1, 1).isLeapYear, true)
            Assert.Equals(DateTime(2026, 1, 1).isLeapYear, false)
        }
    }

    class DaysInMonth {
        ; Regression: an earlier parity-based heuristic returned wrong values for Aug-Dec
        Jan() {
            Assert.Equals(DateTime.DaysInMonth(2026, 1), 31)
        }
        Feb_NonLeap() {
            Assert.Equals(DateTime.DaysInMonth(2026, 2), 28)
        }
        Feb_Leap() {
            Assert.Equals(DateTime.DaysInMonth(2024, 2), 29)
        }
        Mar() {
            Assert.Equals(DateTime.DaysInMonth(2026, 3), 31)
        }
        Apr() {
            Assert.Equals(DateTime.DaysInMonth(2026, 4), 30)
        }
        May() {
            Assert.Equals(DateTime.DaysInMonth(2026, 5), 31)
        }
        Jun() {
            Assert.Equals(DateTime.DaysInMonth(2026, 6), 30)
        }
        Jul() {
            Assert.Equals(DateTime.DaysInMonth(2026, 7), 31)
        }
        Aug() {
            Assert.Equals(DateTime.DaysInMonth(2026, 8), 31)
        }
        Sep() {
            Assert.Equals(DateTime.DaysInMonth(2026, 9), 30)
        }
        Oct() {
            Assert.Equals(DateTime.DaysInMonth(2026, 10), 31)
        }
        Nov() {
            Assert.Equals(DateTime.DaysInMonth(2026, 11), 30)
        }
        Dec() {
            Assert.Equals(DateTime.DaysInMonth(2026, 12), 31)
        }
        Property_ReadsYearAndMonth() {
            Assert.Equals(DateTime(2024, 2, 1).daysInMonth, 29)
            Assert.Equals(DateTime(2026, 2, 1).daysInMonth, 28)
        }
    }

    class FromAHK {
        Complete() {
            dt := DateTime.FromAHK("20260520143045")
            Assert.Equals(dt.year, 2026)
            Assert.Equals(dt.month, 5)
            Assert.Equals(dt.day, 20)
            Assert.Equals(dt.hours, 14)
            Assert.Equals(dt.minutes, 30)
            Assert.Equals(dt.seconds, 45)
        }

        NoOffsetArg_ProducesNaiveValue() {
            dt := DateTime.FromAHK("20260520143045")
            Assert.Equals(dt.offsetMinutes, "")
        }

        WithExplicitOffset() {
            dt := DateTime.FromAHK("20260520143045", -300)
            Assert.Equals(dt.offsetMinutes, -300)
        }

        WithUTCOffset() {
            dt := DateTime.FromAHK("20260520143045", 0)
            Assert.Equals(dt.offsetMinutes, 0)
        }

        InvalidString_Throws() {
            Assert.Throws((*) => DateTime.FromAHK("not-a-date"), ValueError)
        }

        NonStringInput_Throws() {
            Assert.Throws((*) => DateTime.FromAHK(20260520143045), TypeError)
        }
    }

    class FromISO {
        DateOnly_NaiveAtMidnight() {
            dt := DateTime.FromISO("2026-05-20")
            Assert.Equals(dt.year, 2026)
            Assert.Equals(dt.month, 5)
            Assert.Equals(dt.day, 20)
            Assert.Equals(dt.hours, 0)
            Assert.Equals(dt.minutes, 0)
            Assert.Equals(dt.seconds, 0)
            Assert.Equals(dt.isNaive, true)
        }

        DateAndTime_Naive() {
            dt := DateTime.FromISO("2026-05-20T14:30:45")
            Assert.Equals(dt.hours, 14)
            Assert.Equals(dt.minutes, 30)
            Assert.Equals(dt.seconds, 45)
            Assert.Equals(dt.isNaive, true)
        }

        NoSeconds() {
            dt := DateTime.FromISO("2026-05-20T14:30")
            Assert.Equals(dt.hours, 14)
            Assert.Equals(dt.minutes, 30)
            Assert.Equals(dt.seconds, 0)
        }

        SpaceSeparator() {
            dt := DateTime.FromISO("2026-05-20 14:30:45")
            Assert.Equals(dt.hours, 14)
            Assert.Equals(dt.minutes, 30)
            Assert.Equals(dt.seconds, 45)
        }

        ZSuffix_ProducesUTC() {
            dt := DateTime.FromISO("2026-05-20T14:30:45Z")
            Assert.Equals(dt.offsetMinutes, 0)
            Assert.Equals(dt.isUTC, true)
        }

        PositiveOffset() {
            dt := DateTime.FromISO("2026-05-20T14:30:45+05:30")
            Assert.Equals(dt.offsetMinutes, 330)
        }

        NegativeOffset() {
            dt := DateTime.FromISO("2026-05-20T14:30:45-05:00")
            Assert.Equals(dt.offsetMinutes, -300)
        }

        OffsetWithoutColon() {
            dt := DateTime.FromISO("2026-05-20T14:30:45+0530")
            Assert.Equals(dt.offsetMinutes, 330)
        }

        HourOnlyOffset() {
            dt := DateTime.FromISO("2026-05-20T14:30:45-07")
            Assert.Equals(dt.offsetMinutes, -420)
        }

        Milliseconds() {
            dt := DateTime.FromISO("2026-05-20T14:30:45.123Z")
            Assert.Equals(dt.milliseconds, 123)
        }

        FractionalLessThan3Digits_PadsRight() {
            ; ".5" means half a second = 500ms, not 5ms
            dt := DateTime.FromISO("2026-05-20T14:30:45.5Z")
            Assert.Equals(dt.milliseconds, 500)
        }

        FractionalMoreThan3Digits_Truncates() {
            dt := DateTime.FromISO("2026-05-20T14:30:45.123456Z")
            Assert.Equals(dt.milliseconds, 123)
        }

        InvalidString_Throws() {
            Assert.Throws((*) => DateTime.FromISO("not-a-date"), ValueError)
        }

        EmptyString_Throws() {
            Assert.Throws((*) => DateTime.FromISO(""), ValueError)
        }

        InvalidFieldRange_Throws() {
            ; Month 13 reaches the constructor, which validates
            Assert.Throws((*) => DateTime.FromISO("2026-13-01"), ValueError)
        }

        NonString_Throws() {
            Assert.Throws((*) => DateTime.FromISO(20260520), TypeError)
        }

        class RoundTrip {
            RoundTripsThroughToISO_UTC() {
                input := "2026-05-20T14:30:45Z"
                Assert.Equals(DateTime.FromISO(input).ToISO(), input)
            }

            RoundTripsThroughToISO_Offset() {
                input := "2026-05-20T14:30:45+05:30"
                Assert.Equals(DateTime.FromISO(input).ToISO(), input)
            }

            RoundTripsThroughToISO_Naive() {
                input := "2026-05-20T14:30:45"
                Assert.Equals(DateTime.FromISO(input).ToISO(), input)
            }

            RoundTripsThroughToISO_Milliseconds() {
                input := "2026-05-20T14:30:45.123Z"
                Assert.Equals(DateTime.FromISO(input).ToISO(), input)
            }
        }

        ; test corpus from https://tc39.es/proposal-uniform-interchange-date-parsing/cases.html
        class ECMAScriptConformance {
            PositiveLeapSecond() {
                DateTime.FromISO("1972-06-30T23:59:60Z")
            }

            TooFewFractionalSecondDigits() {
                dt := DateTime.FromISO("2019-03-26T14:00:00.9Z")
                Assert.Equals(dt.ToISO(), "2019-03-26T14:00:00.900Z")
            }

            TooManyFractionalSecondDigits() {
                dt := DateTime.FromISO("1969-03-26T14:00:00.4999Z")
                Assert.Equals(dt.ToISO(), "1969-03-26T14:00:00.499Z")
            }

            LowercaseTimeDesignator() {
                dt := DateTime.FromISO("2019-03-26t14:00Z")
                Assert.Equals(dt.ToISO(), "2019-03-26T14:00:00Z")
            }

            LowercaseUTCDesignator() {
                dt := DateTime.FromISO("2019-03-26T14:00z")
                Assert.Equals(dt.ToISO(), "2019-03-26T14:00:00Z")
            }

            CommaAsDecimalSign() {
                dt := DateTime.FromISO("2019-03-26T14:00:00,999Z")
                Assert.Equals(dt.milliseconds, 999)
            }

            HoursOnlyOffset() {
                dt := DateTime.FromISO("2019-03-26T10:00-04")
                Assert.Equals(dt.ToISO(), "2019-03-26T10:00:00-04:00")
            }

            OOBDayOfMonth() => Assert.Throws(() => DateTime.FromISO("2019-02-30"), ValueError)

            TimePastEndOfDay() => Assert.Throws(() => DateTime.FromISO("2019-03-25T24:01Z"), ValueError)

            UTCOffsetTooLarge() => Assert.Throws(() => DateTime.FromISO("2019-03-26T14:00+24:00"), ValueError)

            UnusedLeapSecond() => Assert.Throws(() => DateTime.FromISO("2018-06-30T23:59:60Z"), ValueError)

            BogusLeapSecond() => Assert.Throws(() => DateTime.FromISO("2019-03-26T23:59:60Z"), ValueError)

            ReallyBogusLeapSecond() => Assert.Throws(() => DateTime.FromISO("2019-03-26T13:59:60Z"), ValueError)

            ZeroUTCOffsetWithoutTime() => Assert.Throws(() => DateTime.FromISO("2019-03-26Z"), ValueError)

            PositiveUTCOffsetWithoutTime() => Assert.Throws(() => DateTime.FromISO("2019-03-26+01:00"), ValueError)

            NegativeUTCOffsetWithoutTime() => Assert.Throws(() => DateTime.FromISO("2019-03-26-04:00"), ValueError)

            TooManyExpandedYearDigits() => Assert.Throws(() => DateTime.FromISO("+0002019-03-26T14:00Z"), ValueError)

            TooFewExpandedYearDigits() => Assert.Throws(() => DateTime.FromISO("+2019-03-26T14:00Z"), ValueError)

            TooManyUnsignedYearDigits() => Assert.Throws(() => DateTime.FromISO("002019-03-26T14:00Z"), ValueError)
        
            TooFewUnsignedYearDigits() => Assert.Throws(() => DateTime.FromISO("019-03-26T14:00Z"), ValueError)
        
            NonZMilitaryDesignationLetterOffset() => Assert.Throws(() => DateTime.FromISO("2019-03-26T10:00Q"), ValueError)

            HazardousNonZMilitaryDesignationLetterOffset() => Assert.Throws(() => DateTime.FromISO("2019-03-26T10:00T"), ValueError)

            SpaceAsTimeDesignator() {
                ; Not strictly allowed by ISO 8601 but commonly supported - e.g. JavaScript
                dt := DateTime.FromISO("2019-03-26 14:00Z")
                Assert.Equals(dt.ToISO(), "2019-03-26T14:00:00Z")
            }

            NoDigitsAfterDecimalSign() => Assert.Throws(() => DateTime.FromISO("2019-03-26T14:00:00."), ValueError)
        }
    }

    class ToAHK {
        ToAHK_PadsAllFields() {
            dt := DateTime(2026, 1, 2, 3, 4, 5)
            Assert.Equals(dt.ToAHK(), "20260102030405")
        }

        ToAHK_DropsMilliseconds() {
            dt := DateTime(2026, 5, 20, 14, 30, 45, 999)
            Assert.Equals(dt.ToAHK(), "20260520143045")
        }

        ToAHK_DropsOffset() {
            dt := DateTime(2026, 5, 20, 14, 30, 45, 0, -300)
            Assert.Equals(dt.ToAHK(), "20260520143045")
        }
    }

    class ToISO {
        ToISO_NaiveValue_NoSuffix() {
            dt := DateTime(2026, 5, 20, 14, 30, 45)
            Assert.Equals(dt.ToISO(), "2026-05-20T14:30:45")
        }

        ToISO_UTC_ZSuffix() {
            dt := DateTime(2026, 5, 20, 14, 30, 45, 0, 0)
            Assert.Equals(dt.ToISO(), "2026-05-20T14:30:45Z")
        }

        ToISO_PositiveOffset() {
            dt := DateTime(2026, 5, 20, 14, 30, 45, 0, 330)
            Assert.Equals(dt.ToISO(), "2026-05-20T14:30:45+05:30")
        }

        ToISO_NegativeOffset() {
            dt := DateTime(2026, 5, 20, 14, 30, 45, 0, -300)
            Assert.Equals(dt.ToISO(), "2026-05-20T14:30:45-05:00")
        }

        ToISO_NonZeroMilliseconds_Included() {
            dt := DateTime(2026, 5, 20, 14, 30, 45, 123, 0)
            Assert.Equals(dt.ToISO(), "2026-05-20T14:30:45.123Z")
        }

        ToISO_ZeroMilliseconds_Omitted() {
            dt := DateTime(2026, 5, 20, 14, 30, 45, 0, 0)
            Assert.Equals(dt.ToISO(), "2026-05-20T14:30:45Z")
        }
    }

    class AssumeOffset {
        AssumeUTC_OnNaive_StampsZero() {
            dt := DateTime(2026, 5, 20).AssumeUTC()
            Assert.Equals(dt.offsetMinutes, 0)
            Assert.Equals(dt.isUTC, true)
        }

        AssumeOffset_OnNaive_StampsGivenOffset() {
            dt := DateTime(2026, 5, 20).AssumeOffset(330)
            Assert.Equals(dt.offsetMinutes, 330)
        }

        AssumeOffset_OnZoned_Throws() {
            Assert.Throws((*) => DateTime(2026, 5, 20, 0, 0, 0, 0, 0).AssumeUTC(), Error)
        }

        AssumeOffset_PreservesWallClock() {
            dt := DateTime(2026, 5, 20, 14, 30, 45, 100).AssumeUTC()
            Assert.Equals(dt.year, 2026)
            Assert.Equals(dt.month, 5)
            Assert.Equals(dt.day, 20)
            Assert.Equals(dt.hours, 14)
            Assert.Equals(dt.minutes, 30)
            Assert.Equals(dt.seconds, 45)
            Assert.Equals(dt.milliseconds, 100)
        }
    }

    class WithOffset {
        WithOffset_UTCToPositive_ShiftsForward() {
            ; 14:00 UTC viewed from +05:00 is 19:00
            dt := DateTime(2026, 5, 20, 14, 0, 0, 0, 0).WithOffset(300)
            Assert.Equals(dt.hours, 19)
            Assert.Equals(dt.offsetMinutes, 300)
        }

        WithOffset_PositiveToUTC_WrapsAcrossDay() {
            ; 01:00 +05:00 is 20:00 the previous day in UTC
            dt := DateTime(2026, 5, 20, 1, 0, 0, 0, 300).WithOffset(0)
            Assert.Equals(dt.day, 19)
            Assert.Equals(dt.hours, 20)
            Assert.Equals(dt.offsetMinutes, 0)
        }

        WithOffset_NegativeToUTC_ShiftsForward() {
            ; 22:00 -05:00 is 03:00 next day UTC
            dt := DateTime(2026, 5, 20, 22, 0, 0, 0, -300).WithOffset(0)
            Assert.Equals(dt.day, 21)
            Assert.Equals(dt.hours, 3)
        }

        WithOffset_OnNaive_Throws() {
            Assert.Throws((*) => DateTime(2026, 5, 20).WithOffset(0), Error)
        }
    }

    class AddYears {
        AddYears_Positive() {
            dt := DateTime(2026, 5, 20).AddYears(1)
            Assert.Equals(dt.year, 2027)
            Assert.Equals(dt.month, 5)
            Assert.Equals(dt.day, 20)
        }

        AddYears_Negative() {
            dt := DateTime(2026, 5, 20).AddYears(-1)
            Assert.Equals(dt.year, 2025)
        }

        AddYears_LeapDayToNonLeap_ClampsTo28() {
            dt := DateTime(2024, 2, 29).AddYears(1)
            Assert.Equals(dt.year, 2025)
            Assert.Equals(dt.month, 2)
            Assert.Equals(dt.day, 28)
        }

        AddYears_PreservesOffset() {
            dt := DateTime(2026, 5, 20, 0, 0, 0, 0, 300).AddYears(1)
            Assert.Equals(dt.offsetMinutes, 300)
        }

        AddYears_BeyondMaxYear_Throws() {
            Assert.Throws((*) => DateTime(9999, 5, 20).AddYears(1), ValueError)
        }

        AddYears_DoesNotMutateOriginal() {
            dt := DateTime(2026, 5, 20)
            dt.AddYears(1)
            Assert.Equals(dt.year, 2026)
        }
    }

    class AddMonths {
        AddMonths_WithinYear() {
            dt := DateTime(2026, 5, 20).AddMonths(3)
            Assert.Equals(dt.year, 2026)
            Assert.Equals(dt.month, 8)
            Assert.Equals(dt.day, 20)
        }

        AddMonths_CrossesYear() {
            dt := DateTime(2026, 11, 20).AddMonths(3)
            Assert.Equals(dt.year, 2027)
            Assert.Equals(dt.month, 2)
        }

        AddMonths_Negative_CrossesYear() {
            dt := DateTime(2026, 2, 15).AddMonths(-3)
            Assert.Equals(dt.year, 2025)
            Assert.Equals(dt.month, 11)
        }

        AddMonths_Jan31PlusOne_ClampsToFebLastDay() {
            ; 2026 not a leap year
            dt := DateTime(2026, 1, 31).AddMonths(1)
            Assert.Equals(dt.month, 2)
            Assert.Equals(dt.day, 28)
        }

        AddMonths_Jan31PlusOne_LeapYear_ClampsTo29() {
            dt := DateTime(2024, 1, 31).AddMonths(1)
            Assert.Equals(dt.month, 2)
            Assert.Equals(dt.day, 29)
        }

        AddMonths_LargePositive() {
            dt := DateTime(2026, 5, 20).AddMonths(25)
            Assert.Equals(dt.year, 2028)
            Assert.Equals(dt.month, 6)
        }

        AddMonths_PreservesOffset() {
            dt := DateTime(2026, 5, 20, 0, 0, 0, 0, -300).AddMonths(1)
            Assert.Equals(dt.offsetMinutes, -300)
        }
    }

    class AddDays {
        AddDays_WithinMonth() {
            dt := DateTime(2026, 5, 20).AddDays(5)
            Assert.Equals(dt.day, 25)
        }

        AddDays_CrossesMonth() {
            dt := DateTime(2026, 5, 20).AddDays(15)
            Assert.Equals(dt.month, 6)
            Assert.Equals(dt.day, 4)
        }

        AddDays_CrossesYear() {
            dt := DateTime(2026, 12, 30).AddDays(5)
            Assert.Equals(dt.year, 2027)
            Assert.Equals(dt.month, 1)
            Assert.Equals(dt.day, 4)
        }

        ; Regression for the DaysInMonth parity bug
        AddDays_365_NonLeap_LandsOneYearLater() {
            dt := DateTime(2026, 5, 20).AddDays(365)
            Assert.Equals(dt.year, 2027)
            Assert.Equals(dt.month, 5)
            Assert.Equals(dt.day, 20)
        }

        AddDays_366_OverLeapYear() {
            ; 2024 is a leap year, so 366 days from Jan 1 2024 is Jan 1 2025
            dt := DateTime(2024, 1, 1).AddDays(366)
            Assert.Equals(dt.year, 2025)
            Assert.Equals(dt.month, 1)
            Assert.Equals(dt.day, 1)
        }

        AddDays_IntoLeapDay() {
            dt := DateTime(2024, 2, 28).AddDays(1)
            Assert.Equals(dt.month, 2)
            Assert.Equals(dt.day, 29)
        }

        AddDays_Negative_CrossesMonth() {
            dt := DateTime(2026, 5, 1).AddDays(-1)
            Assert.Equals(dt.month, 4)
            Assert.Equals(dt.day, 30)
        }

        AddDays_Negative_CrossesYear() {
            dt := DateTime(2026, 1, 5).AddDays(-10)
            Assert.Equals(dt.year, 2025)
            Assert.Equals(dt.month, 12)
            Assert.Equals(dt.day, 26)
        }
    }

    class AddHours {
        AddHours_WithinDay() {
            dt := DateTime(2026, 5, 20, 10, 0, 0).AddHours(5)
            Assert.Equals(dt.hours, 15)
        }

        AddHours_CrossesDay() {
            dt := DateTime(2026, 5, 20, 22, 0, 0).AddHours(5)
            Assert.Equals(dt.day, 21)
            Assert.Equals(dt.hours, 3)
        }

        AddHours_Negative_CrossesDay() {
            dt := DateTime(2026, 5, 20, 2, 0, 0).AddHours(-5)
            Assert.Equals(dt.day, 19)
            Assert.Equals(dt.hours, 21)
        }
    }

    class AddMinutes {
        AddMinutes_WithinHour() {
            dt := DateTime(2026, 5, 20, 10, 0, 0).AddMinutes(30)
            Assert.Equals(dt.minutes, 30)
        }

        AddMinutes_CrossesHour() {
            dt := DateTime(2026, 5, 20, 10, 45, 0).AddMinutes(30)
            Assert.Equals(dt.hours, 11)
            Assert.Equals(dt.minutes, 15)
        }

        AddMinutes_FullDay_CrossesDate() {
            dt := DateTime(2026, 5, 20, 10, 0, 0).AddMinutes(1440)
            Assert.Equals(dt.day, 21)
            Assert.Equals(dt.hours, 10)
        }
    }

    class AddSeconds {
        AddSeconds_CrossesMinute() {
            dt := DateTime(2026, 5, 20, 10, 0, 45).AddSeconds(30)
            Assert.Equals(dt.minutes, 1)
            Assert.Equals(dt.seconds, 15)
        }

        AddSeconds_Negative_CrossesMinute() {
            dt := DateTime(2026, 5, 20, 10, 1, 15).AddSeconds(-30)
            Assert.Equals(dt.minutes, 0)
            Assert.Equals(dt.seconds, 45)
        }
    }

    class AddMilliseconds {
        AddMilliseconds_CrossesSecond() {
            dt := DateTime(2026, 5, 20, 10, 0, 0, 500).AddMilliseconds(750)
            Assert.Equals(dt.seconds, 1)
            Assert.Equals(dt.milliseconds, 250)
        }
    }

    class ToString {
        ToString_AHK_DelegatesToToAHK() {
            dt := DateTime(2026, 5, 20, 14, 30, 45)
            Assert.Equals(dt.ToString("AHK"), "20260520143045")
        }

        ToString_ISO_DelegatesToToISO() {
            dt := DateTime(2026, 5, 20, 14, 30, 45, 0, 0)
            Assert.Equals(dt.ToString("ISO"), "2026-05-20T14:30:45Z")
        }

        ToString_CaseInsensitive() {
            dt := DateTime(2026, 5, 20)

            Assert.Equals(!!dt.isNaive, true)
            Assert.Equals(dt.ToString("ahk"), "20260520000000")
            Assert.Equals(dt.ToString("Iso"), "2026-05-20T00:00:00")
        }
    }
}
