module Erp::Deliveries
  class Delivery < ApplicationRecord
    belongs_to :creator, class_name: "Erp::User"
    belongs_to :employee, class_name: "Erp::User"
    
    if Erp::Core.available?("sales")
      belongs_to :order, class_name: "Erp::Sales::Order"
    end
    
    if Erp::Core.available?("contacts")
      belongs_to :contact, class_name: "Erp::Contacts::Contact"
      belongs_to :supplier, class_name: "Erp::Contacts::Contact"
      def contact_name
        contact.present? ? contact.contact_name : ''
      end
      def supplier_name
        supplier.present? ? supplier.contact_name : ''
      end
    end
    
    if Erp::Core.available?("warehouses")
      belongs_to :warehouse, class_name: "Erp::Warehouses::Warehouse"
      def warehouse_name
        warehouse.present? ? warehouse.warehouse_name : ''
      end
    end
    
    has_many :delivery_details, inverse_of: :delivery, dependent: :destroy
    accepts_nested_attributes_for :delivery_details, :reject_if => lambda { |a| a[:order_detail_id].blank? || a[:quantity].blank? }
    
    # class const
    TYPE_IMPORT = 'import'
    TYPE_EXPORT = 'export'
    # Filters
    def self.filter(query, params)
      params = params.to_unsafe_hash
      and_conds = []
      show_archived = false
      
      #filters
      if params["filters"].present?
        params["filters"].each do |ft|
          or_conds = []
          ft[1].each do |cond|
            # in case filter is show archived
            if cond[1]["name"] == 'show_archived'
              show_archived = true
            else
              or_conds << "#{cond[1]["name"]} = '#{cond[1]["value"]}'"
            end
          end
          and_conds << '('+or_conds.join(' OR ')+')' if !or_conds.empty?
        end
      end
      
      # show archived items condition - default: false
      show_archived = false
      
      #filters
      if params["filters"].present?
        params["filters"].each do |ft|
          or_conds = []
          ft[1].each do |cond|
            # in case filter is show archived
            if cond[1]["name"] == 'show_archived'
              # show archived items
              show_archived = true
            else
              or_conds << "#{cond[1]["name"]} = '#{cond[1]["value"]}'"
            end
          end
          and_conds << '('+or_conds.join(' OR ')+')' if !or_conds.empty?
        end
      end
      
      #keywords
      if params["keywords"].present?
        params["keywords"].each do |kw|
          or_conds = []
          kw[1].each do |cond|
            or_conds << "LOWER(#{cond[1]["name"]}) LIKE '%#{cond[1]["value"].downcase.strip}%'"
          end
          and_conds << '('+or_conds.join(' OR ')+')'
        end
      end

      # join with users table for search creator
      query = query.joins(:creator)
      
      # showing archived items if show_archived is not true
      query = query.where(archived: false) if show_archived == false
      
      # add conditions to query
      query = query.where(and_conds.join(' AND ')) if !and_conds.empty?
      
      return query
    end
    
    def self.search(params)
      query = self.all
      query = self.filter(query, params)
      
      # order
      if params[:sort_by].present?
        order = params[:sort_by]
        order += " #{params[:sort_direction]}" if params[:sort_direction].present?
        
        query = query.order(order)
      end
      
      return query
    end
    
    # data for dataselect ajax
    def self.dataselect(keyword='')
      query = self.all
      
      if keyword.present?
        keyword = keyword.strip.downcase
        query = query.where('LOWER(name) LIKE ?', "%#{keyword}%")
      end
      
      query = query.limit(8).map{|delivery| {value: delivery.id, text: delivery.code} }
    end
    
    def creator_name
      creator.present? ? creator.name : ''
    end
    
    def employee_name
      employee.present? ? employee.name : ''
    end
    
    def archive
			update_attributes(archived: true)
		end
    
    def unarchive
			update_attributes(archived: false)
		end
    
    def self.archive_all
			update_all(archived: true)
		end
    
    def self.unarchive_all
			update_all(archived: false)
		end
    
    def count_delivery_detail
      delivery_details.count
    end
    
    def total_delivery_invoice
      total = 0.0
      delivery_details.each do |dt|
        total += dt.total
      end
      
      return total
    end
    
    def get_detail_by_order_detail(order_detail)
      delivery_details.where(order_detail_id: order_detail.id).first
    end
  end
end
