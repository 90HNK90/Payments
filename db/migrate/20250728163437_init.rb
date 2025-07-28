class Init < ActiveRecord::Migration[7.2]
  def up
    execute <<-SQL
      CREATE TYPE job_status AS ENUM ('pending', 'success', 'failed');
      CREATE TYPE currency AS ENUM ('AUD', 'USD', 'SGD', 'VND');
      CREATE TYPE payment_status AS ENUM ('pending', 'exporting', 'exported');
    SQL

    # --- Tables ---

    create_table :configuration, id: :uuid do |t|
      t.string :name, null: false
      t.string :value, null: false
      t.boolean :active, null: false
      t.timestamps
    end

    create_table :company, id: :uuid do |t|
      t.string :name, limit: 255, null: false
      t.boolean :active, null: false, default: true
    end

    create_table :job, id: :uuid do |t|
      t.enum :status, enum_type: 'job_status', default: 'pending', null: false
      t.datetime :executed_at
      t.datetime :updated_at
      t.string :output
    end

    create_table :payments, id: :uuid do |t|
      t.uuid :employee_id, null: false
      t.uuid :batch_id, null: false
      t.string :bsb, limit: 6, null: false
      t.string :account, limit: 9, null: false
      t.bigint :amount_cents, null: false
      t.enum :currency, enum_type: 'currency', default: 'AUD', null: false
      t.date :pay_date, null: false
      t.enum :status, enum_type: 'payment_status', default: 'pending', null: false

      # Foreign key references
      t.references :company, type: :uuid, null: false, foreign_key: { to_table: :company }
      t.references :job, type: :uuid, null: true, foreign_key: { to_table: :job }

      t.timestamps
    end

    # --- Indexes ---

    add_index :company, :name, unique: true, where: "active = true", name: 'one_active_company_name'

    add_index :payments, [:employee_id, :company_id, :batch_id],
              unique: true,
              where: "status = 'pending'",
              name: 'one_pending_payment_per_batch'
  end

  def down
    drop_table :payments
    drop_table :job
    drop_table :company
    drop_table :configuration

    execute <<-SQL
      DROP TYPE payment_status;
      DROP TYPE currency;
      DROP TYPE job_status;
    SQL
  end
end
