class MasterData < ActiveRecord::Migration[7.2]
  def up
    Company.create!(
      id: 'a8a8f2d0-2e6a-4b9e-8b0c-1e1a1d1e1a1d',
      name: 'Default Company',
      active: true
    )
    Company.create!(
      id: 'b8b8f2d0-2e6a-4b9e-8b0c-1e1a1d1e1a1e',
      name: 'Second Company',
      active: true
    )

    # --- Configuration Master Data ---
    Configuration.create!(
      id: 'd8d8f2d0-2e6a-4b9e-8b0c-1e1a1d1e1a1a',
      name: 'file_path',
      value: 'payments/payments_{timestamp}.txt',
      active: true
    )
  end

  def down
    Configuration.where(name: ['file_path']).delete_all
    Company.where(name: ['Default Company', 'Second Company']).delete_all
  end
end
