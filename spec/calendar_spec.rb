require "bank_time/calendar"
require "time"

describe BankTime::Calendar do
  describe ".load" do
    context "when given a valid calendar" do
      subject { BankTime::Calendar.load("weekdays") }

      it "loads the yaml file" do
        YAML.should_receive(:load_file) do |path|
          path.should match(/weekdays\.yml$/)
        end.and_return({})
        subject
      end

      it { should be_a BankTime::Calendar }
    end

    context "when given an invalid calendar" do
      subject { BankTime::Calendar.load("invalid-calendar") }
      specify { ->{ subject }.should raise_error }
    end
  end

  describe "#set_business_days" do
    let(:calendar) { BankTime::Calendar.new({}) }
    let(:business_days) { [] }
    subject { calendar.set_business_days(business_days) }

    context "when given valid business days" do
      let(:business_days) { %w( mon fri ) }
      before { subject }

      it "assigns them" do
        calendar.business_days.should == business_days
      end

      context "that are unnormalised" do
        let(:business_days) { %w( Monday Friday ) }
        it "normalises them" do
          calendar.business_days.should == %w( mon fri )
        end
      end
    end

    context "when given an invalid business day" do
      let(:business_days) { %w( Notaday ) }
      specify { ->{ subject }.should raise_exception }
    end

    context "when given nil" do
      let(:business_days) { nil }
      it "uses the default business days" do
        calendar.business_days.should == calendar.default_business_days
      end
    end
  end

  describe "#set_holidays" do
    let(:calendar) { BankTime::Calendar.new({}) }
    let(:holidays) { [] }
    before { calendar.set_holidays(holidays) }
    subject { calendar.holidays }

    context "when given valid business days" do
      let(:holidays) { ["1st Jan, 2013"] }

      it { should_not be_empty }

      it "converts them to Date objects" do
        subject.each { |h| h.should be_a Date }
      end
    end

    context "when given nil" do
      let(:holidays) { nil }
      it { should be_empty }
    end
  end

  # A set of examples that are supposed to work when given Date and Time
  # objects. The implementation slightly differs, so i's worth running the
  # tests for both Date *and* Time.
  shared_examples "common" do
    describe "#business_day?" do
      let(:calendar) do
        BankTime::Calendar.new(holidays: ["9am, Tuesday 1st Jan, 2013"])
      end
      subject { calendar.business_day?(day) }

      context "when given a business day" do
        let(:day) { date_class.parse("9am, Wednesday 2nd Jan, 2013") }
        it { should be_true }
      end

      context "when given a non-business day" do
        let(:day) { date_class.parse("9am, Saturday 5th Jan, 2013") }
        it { should be_false }
      end

      context "when given a business day that is a holiday" do
        let(:day) { date_class.parse("9am, Tuesday 1st Jan, 2013") }
        it { should be_false }
      end
    end

    describe "#roll_forward" do
      let(:calendar) do
        BankTime::Calendar.new(holidays: ["Tuesday 1st Jan, 2013"])
      end
      subject { calendar.roll_forward(date) }

      context "given a business day" do
        let(:date) { date_class.parse("Wednesday 2nd Jan, 2013") }
        it { should == date }
      end

      context "given a non-business day" do
        context "with a business day following it" do
          let(:date) { date_class.parse("Tuesday 1st Jan, 2013") }
          it { should == date + day_interval }
        end

        context "followed by another non-business day" do
          let(:date) { date_class.parse("Saturday 5th Jan, 2013") }
          it { should == date + 2 * day_interval }
        end
      end
    end

    describe "#roll_backward" do
      let(:calendar) do
        BankTime::Calendar.new(holidays: ["Tuesday 1st Jan, 2013"])
      end
      subject { calendar.roll_backward(date) }

      context "given a business day" do
        let(:date) { date_class.parse("Wednesday 2nd Jan, 2013") }
        it { should == date }
      end

      context "given a non-business day" do
        context "with a business day preceeding it" do
          let(:date) { date_class.parse("Tuesday 1st Jan, 2013") }
          it { should == date - day_interval }
        end

        context "preceeded by another non-business day" do
          let(:date) { date_class.parse("Sunday 6th Jan, 2013") }
          it { should == date - 2 * day_interval }
        end
      end
    end

    describe "#next_business_day" do
      let(:calendar) do
        BankTime::Calendar.new(holidays: ["Tuesday 1st Jan, 2013"])
      end
      subject { calendar.next_business_day(date) }

      context "given a business day" do
        let(:date) { date_class.parse("Wednesday 2nd Jan, 2013") }
        it { should == date + day_interval }
      end

      context "given a non-business day" do
        context "with a business day following it" do
          let(:date) { date_class.parse("Tuesday 1st Jan, 2013") }
          it { should == date + day_interval }
        end

        context "followed by another non-business day" do
          let(:date) { date_class.parse("Saturday 5th Jan, 2013") }
          it { should == date + 2 * day_interval }
        end
      end
    end

    describe "#add_business_days" do
      let(:calendar) do
        BankTime::Calendar.new(holidays: ["Tuesday 1st Jan, 2013"])
      end
      let(:delta) { 2 }
      subject { calendar.add_business_days(date, delta) }

      context "given a business day" do
        context "and a period that includes only business days" do
          let(:date) { date_class.parse("Wednesday 2nd Jan, 2013") }
          it { should == date + delta * day_interval }
        end

        context "and a period that includes a weekend" do
          let(:date) { date_class.parse("Friday 4th Jan, 2013") }
          it { should == date + (delta + 2) * day_interval }
        end

        context "and a period that includes a holiday day" do
          let(:date) { date_class.parse("Monday 31st Dec, 2012") }
          it { should == date + (delta + 1) * day_interval }
        end
      end

      context "given a non-business day" do
        let(:date) { date_class.parse("Tuesday 1st Jan, 2013") }
        it { should == date + (delta + 1) * day_interval }
      end
    end

    describe "#subtract_business_days" do
      let(:calendar) do
        BankTime::Calendar.new(holidays: ["Thursday 3rd Jan, 2013"])
      end
      let(:delta) { 2 }
      subject { calendar.subtract_business_days(date, delta) }

      context "given a business day" do
        context "and a period that includes only business days" do
          let(:date) { date_class.parse("Wednesday 2nd Jan, 2013") }
          it { should == date - delta * day_interval }
        end

        context "and a period that includes a weekend" do
          let(:date) { date_class.parse("Monday 31st Dec, 2012") }
          it { should == date - (delta + 2) * day_interval }
        end

        context "and a period that includes a holiday day" do
          let(:date) { date_class.parse("Friday 4th Jan, 2013") }
          it { should == date - (delta + 1) * day_interval }
        end
      end

      context "given a non-business day" do
        let(:date) { date_class.parse("Thursday 3rd Jan, 2013") }
        it { should == date - (delta + 1) * day_interval }
      end
    end

    describe "#business_days_between" do
      let(:holidays) do
        ["Thu 12/6/2014", "Wed 18/6/2014", "Fri 20/6/2014", "Sun 22/6/2014"]
      end
      let(:calendar) { BankTime::Calendar.new(holidays: holidays) }
      subject { calendar.business_days_between(date_1, date_2) }


      context "starting on a business day" do
        let(:date_1) { date_class.parse("Mon 2/6/2014") }

        context "ending on a business day" do
          context "including only business days" do
            let(:date_2) { date_class.parse("Thu 5/6/2014") }
            it { should == 3 }
          end

          context "including only business days & weekend days" do
            let(:date_2) { date_class.parse("Mon 9/6/2014") }
            it { should == 5 }
          end

          context "including only business days & holidays" do
            let(:date_1) { date_class.parse("Mon 9/6/2014") }
            let(:date_2) { date_class.parse("Fri 13/6/2014") }
            it { should == 3 }
          end

          context "including business, weekend days, and holidays" do
            let(:date_2) { date_class.parse("Fri 13/6/2014") }
            it { should == 8 }
          end
        end

        context "ending on a weekend day" do
          context "including only business days & weekend days" do
            let(:date_2) { date_class.parse("Sun 8/6/2014") }
            it { should == 5 }
          end

          context "including business, weekend days, and holidays" do
            let(:date_2) { date_class.parse("Sat 14/6/2014") }
            it { should == 9 }
          end
        end

        context "ending on a holiday" do
          context "including only business days & holidays" do
            let(:date_1) { date_class.parse("Mon 9/6/2014") }
            let(:date_2) { date_class.parse("Thu 12/6/2014") }
            it { should == 3 }
          end

          context "including business, weekend days, and holidays" do
            let(:date_2) { date_class.parse("Thu 12/6/2014") }
            it { should == 8 }
          end
        end
      end

      context "starting on a weekend" do
        let(:date_1) { date_class.parse("Sat 7/6/2014") }

        context "ending on a business day" do

          context "including only business days & weekend days" do
            let(:date_2) { date_class.parse("Mon 9/6/2014") }
            it { should == 0 }
          end

          context "including business, weekend days, and holidays" do
            let(:date_2) { date_class.parse("Fri 13/6/2014") }
            it { should == 3 }
          end
        end

        context "ending on a weekend day" do
          context "including only business days & weekend days" do
            let(:date_2) { date_class.parse("Sun 8/6/2014") }
            it { should == 0 }
          end

          context "including business, weekend days, and holidays" do
            let(:date_2) { date_class.parse("Sat 14/6/2014") }
            it { should == 4 }
          end
        end

        context "ending on a holiday" do
          context "including business, weekend days, and holidays" do
            let(:date_2) { date_class.parse("Thu 12/6/2014") }
            it { should == 3 }
          end
        end
      end

      context "starting on a holiday" do
        let(:date_1) { date_class.parse("Thu 12/6/2014") }

        context "ending on a business day" do

          context "including only business days & holidays" do
            let(:date_2) { date_class.parse("Fri 13/6/2014") }
            it { should == 0 }
          end

          context "including business, weekend days, and holidays" do
            let(:date_2) { date_class.parse("Thu 19/6/2014") }
            it { should == 3 }
          end
        end

        context "ending on a weekend day" do
          context "including business, weekend days, and holidays" do
            let(:date_2) { date_class.parse("Sun 15/6/2014") }
            it { should == 1 }
          end
        end

        context "ending on a holiday" do
          context "including only business days & holidays" do
            let(:date_1) { date_class.parse("Wed 18/6/2014") }
            let(:date_2) { date_class.parse("Fri 20/6/2014") }
            it { should == 1 }
          end

          context "including business, weekend days, and holidays" do
            let(:date_2) { date_class.parse("Wed 18/6/2014") }
            it { should == 3 }
          end
        end
      end

      context "if a calendar has a holiday on a non-working (weekend) day" do
        context "for a range less than a week long" do
          let(:date_1) { date_class.parse("Thu 19/6/2014") }
          let(:date_2) { date_class.parse("Tue 24/6/2014") }
          it { should == 2 }
        end
        context "for a range more than a week long" do
          let(:date_1) { date_class.parse("Mon 16/6/2014") }
          let(:date_2) { date_class.parse("Tue 24/6/2014") }
          it { should == 4 }
        end
      end
    end
  end

  context "(using Date objects)" do
    let(:date_class) { Date }
    let(:day_interval) { 1 }

    it_behaves_like "common"
  end

  context "(using Time objects)" do
    let(:date_class) { Time }
    let(:day_interval) { 3600 * 24 }

    it_behaves_like "common"
  end

  context "(using DateTime objects)" do
    let(:date_class) { DateTime }
    let(:day_interval) { 1 }

    it_behaves_like "common"
  end
end

