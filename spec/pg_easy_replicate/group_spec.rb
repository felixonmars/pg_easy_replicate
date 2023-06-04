# frozen_string_literal: true

RSpec.describe(PgEasyReplicate::Group) do
  before { described_class.drop }

  describe ".setup" do
    it "creates the table" do
      described_class.setup

      r =
        PgEasyReplicate::Query.run(
          query: "select * from groups",
          connection_url: connection_url,
          schema: PgEasyReplicate.internal_schema_name,
        )
      expect(r).to eq([])

      columns_sql = <<~SQL
        SELECT column_name, data_type
        FROM information_schema.columns
        WHERE table_schema = '#{PgEasyReplicate.internal_schema_name}'
        AND table_name = 'groups';
      SQL
      columns =
        PgEasyReplicate::Query.run(
          query: columns_sql,
          connection_url: connection_url,
          schema: PgEasyReplicate.internal_schema_name,
        )
      expect(columns).to eq(
        [
          { "column_name" => "id", "data_type" => "integer" },
          { "column_name" => "name", "data_type" => "text" },
          { "column_name" => "table_names", "data_type" => "text" },
          { "column_name" => "schema_name", "data_type" => "text" },
          {
            "column_name" => "created_at",
            "data_type" => "timestamp without time zone",
          },
          {
            "column_name" => "started_at",
            "data_type" => "timestamp without time zone",
          },
          {
            "column_name" => "completed_at",
            "data_type" => "timestamp without time zone",
          },
        ],
      )
    end
  end

  describe ".drop" do
    it "drops the table" do
      described_class.setup
      described_class.drop

      sql = <<~SQL
        SELECT EXISTS (
          SELECT FROM
              pg_tables
          WHERE
              schemaname = '#{PgEasyReplicate.internal_schema_name}' AND
              tablename  = 'groups'
          );
      SQL
      r =
        PgEasyReplicate::Query.run(
          query: sql,
          connection_url: connection_url,
          schema: PgEasyReplicate.internal_schema_name,
        )
      expect(r).to eq([{ "exists" => "f" }])
    end
  end

  describe ".create" do
    before { described_class.setup }
    after { described_class.drop }

    it "adds a row with just the required fields" do
      described_class.create({ name: "test" })

      r =
        PgEasyReplicate::Query.run(
          query: "select * from groups",
          connection_url: connection_url,
          schema: PgEasyReplicate.internal_schema_name,
        )
      expect(r.first["name"]).to eq("test")
    end

    it "adds a row with table names and schema" do
      described_class.create(
        { name: "test", table_names: "table1, table2", schema_name: "foo" },
      )

      r =
        PgEasyReplicate::Query.run(
          query: "select * from groups",
          connection_url: connection_url,
          schema: PgEasyReplicate.internal_schema_name,
        )
      expect(r.first["name"]).to eq("test")
      expect(r.first["table_names"]).to eq("table1, table2")
      expect(r.first["schema_name"]).to eq("foo")
    end

    it "captures the error" do
      expect { described_class.create({}) }.to raise_error(
        SystemExit,
        /Adding group entry failed: ERROR:  null value in column "name"/,
      )
    end
  end

  describe ".find" do
    before { described_class.setup }
    after { described_class.drop }

    it "returns a row" do
      described_class.create(
        { name: "test", table_names: "table1, table2", schema_name: "foo" },
      )

      expect(described_class.find("test")).to include(
        hash_including(
          "completed_at" => nil,
          "id" => kind_of(String),
          "name" => "test",
          "schema_name" => "foo",
          "started_at" => nil,
          "table_names" => "table1, table2",
        ),
      )
    end
  end

  describe ".update" do
    before { described_class.setup }
    after { described_class.drop }

    it "updates the started_at and completed_at successfully" do
      described_class.create(
        { name: "test", table_names: "table1, table2", schema_name: "foo" },
      )
      r =
        described_class.update(
          group_name: "test",
          started_at: Time.now,
          completed_at: Time.now,
        )

      expect(r).to include(
        hash_including(
          "completed_at" => kind_of(String),
          "id" => kind_of(String),
          "name" => "test",
          "schema_name" => "foo",
          "started_at" => kind_of(String),
          "table_names" => "table1, table2",
        ),
      )

      expect(described_class.find("test")).to include(
        hash_including(
          "completed_at" => kind_of(String),
          "id" => kind_of(String),
          "name" => "test",
          "schema_name" => "foo",
          "started_at" => kind_of(String),
          "table_names" => "table1, table2",
        ),
      )

      expect(
        Time.parse(described_class.find("test").first["completed_at"]),
      ).to be_a(Time)
      expect(
        Time.parse(described_class.find("test").first["started_at"]),
      ).to be_a(Time)
    end
  end

  describe ".delete" do
    before { described_class.setup }
    after { described_class.drop }

    it "returns a row" do
      described_class.create(
        { name: "test", table_names: "table1, table2", schema_name: "foo" },
      )
      described_class.delete("test")

      expect(described_class.find("test")).to eq([])
    end
  end
end
