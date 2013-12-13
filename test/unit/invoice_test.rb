# encoding: utf-8
require File.dirname(__FILE__) + '/../test_helper'

class InvoiceTest < ActiveSupport::TestCase

  fixtures :clients, :invoices, :invoice_lines, :taxes, :companies, :people, :bank_infos

  def setup
    User.current=nil
    Haltr::TestHelper.fix_invoice_totals
  end

  test "due dates" do
    date = Date.new(2000,12,1)
    i = IssuedInvoice.new(:client=>clients(:client1),:project=>Project.find(2),:date=>date,:number=>111)
    i.invoice_lines << invoice_lines(:invoice1_l1).dup
    i.save!
    assert_equal date, i.due_date
    i = IssuedInvoice.new(:client=>clients(:client1),:project=>Project.find(2),:date=>date,:number=>222,:terms=>"1m15")
    i.invoice_lines << invoice_lines(:invoice1_l1).dup
    i.save!
    assert_equal Date.new(2001,1,15), i.due_date
    i = IssuedInvoice.new(:client=>clients(:client1),:project=>Project.find(2),:date=>date,:number=>333,:terms=>"3m15")
    i.invoice_lines << invoice_lines(:invoice1_l1).dup
    i.save!
    assert_equal Date.new(2001,3,15), i.due_date
  end

  test "do not modify due dates on save" do
    i = invoices(:invoice1)
    d = Date.new(2010,1,1)
    i.due_date = d
    i.save!
    i = Invoice.find i.id
    assert_equal Date.new(2008,12,1), i.due_date
  end
 
  test "invoice number increment right" do
    assert_equal "not_an_i1", IssuedInvoice.increment_right("not_an_i")
    assert_equal "1", IssuedInvoice.increment_right(nil)
    assert_equal "2011/2", IssuedInvoice.increment_right("2011/1")
    assert_equal "2011-2", IssuedInvoice.increment_right("2011-1")
    assert_equal "11/002", IssuedInvoice.increment_right("11/001")
    assert_equal "0032", IssuedInvoice.increment_right("0031")
    assert_equal "1000", IssuedInvoice.increment_right("999")
  end

  test "sort draft invoices" do
    assert_equal(-1 , invoices(:draft) <=> invoices(:invoice1))
    assert_equal 1 , invoices(:invoice1) <=> invoices(:draft)
    assert_equal 0 , invoices(:draft) <=> invoices(:draft)
  end

  test "invoice contable validation" do
    assert_equal 100, invoices(:invoices_003).subtotal_without_discount.dollars
    assert_equal 100, invoices(:invoices_003).taxable_base.dollars
    assert_equal 18, invoices(:invoices_003).tax_amount.dollars
    assert_equal 1, invoices(:invoices_003).taxes_uniq.size
    assert_equal 100, invoices(:invoices_003).subtotal.dollars
    assert_equal 0, invoices(:invoices_003).discount.dollars
    assert_equal 118, invoices(:invoices_003).total.dollars
    assert_equal "J", invoices(:invoices_003).persontypecode

    assert_equal 100, invoices(:invoices_002).subtotal_without_discount.dollars
    assert_equal 85, invoices(:invoices_002).taxable_base.dollars
    assert_equal 15.30, invoices(:invoices_002).tax_amount.dollars
    assert_equal 1, invoices(:invoices_002).taxes_uniq.size
    assert_equal 85, invoices(:invoices_002).subtotal.dollars
    assert_equal 15, invoices(:invoices_002).discount.dollars
    assert_equal 100.30, invoices(:invoices_002).total.dollars
    assert_equal "J", invoices(:invoices_002).persontypecode

    assert_equal 250, invoices(:invoices_001).subtotal_without_discount.dollars
    assert_equal 225, invoices(:invoices_001).taxable_base.dollars
    assert_equal 2.7, invoices(:invoices_001).tax_amount.dollars
    assert_equal(-13.5, invoices(:invoices_001).tax_amount(taxes(:taxes_006)).dollars)
    assert_equal 16.2, invoices(:invoices_001).tax_amount(taxes(:taxes_005)).dollars
    assert_equal 7.2, invoices(:invoices_001).tax_amount(taxes(:taxes_007)).dollars
    assert_equal(-7.2, invoices(:invoices_001).tax_amount(taxes(:taxes_008)).dollars)
    assert_equal 4, invoices(:invoices_001).taxes_uniq.size
    assert_equal 225, invoices(:invoices_001).subtotal.dollars
    assert_equal 25, invoices(:invoices_001).discount.dollars
    assert_equal 227.7, invoices(:invoices_001).total.dollars
    assert_equal "F", invoices(:invoices_001).persontypecode
  end

  test "currency to upcase" do
    i=invoices(:invoices_003)
    assert_equal "EUR", i.currency
    i.currency="usd"
    assert_equal "USD", i.currency
  end

  test "taxes_by_category" do
    i=invoices(:i5)
    categories = i.taxes_by_category
    assert_equal 1, categories.size
    assert_equal 1, categories["VAT"].size
    assert categories["VAT"]["E"]
  end

  test "taxes_without_company_tax" do
    i = invoices(:i5)
    c = companies(:company1)
    assert_equal 1, i.taxes.size
    line = i.invoice_lines.first
    line.taxes << Tax.new(:company => nil, :invoice_line => line, :name => 'VAT', :percent => 99.0, :category => 'XL', :comment => 'This is unique to this invoice line. Company does not have a tax like this.')
    line.save!
    assert_equal 2, i.taxes.size
    assert_equal 4, c.taxes.size
    # invoice i5 and company share one tax, so 2 + 4 - 1 = 5
    assert_equal(5, i.available_taxes.size)
  end

  test "to string" do
    i = invoices(:i7)
    assert i.to_s.split.size > 1
  end

  test "invoice_taxable_base_with_exempts_and_zeros" do
    i = invoices(:i7)
    assert_equal 2, i.invoice_lines.size
    i.invoice_lines[0].taxes = [ Tax.new(:code=>"0.0_E",:name=>"VAT") ]
    i.invoice_lines[1].taxes = [ Tax.new(:code=>"0.0_Z",:name=>"VAT") ]
    i.save
    assert_equal 1, i.invoice_lines[0].taxes.size
    assert_equal 1, i.invoice_lines[1].taxes.size
    assert_equal i.invoice_lines[0].total, i.taxable_base(Tax.new(:code=>"0.0_E",:name=>"VAT"))
    assert_equal i.invoice_lines[1].total,  i.taxable_base(Tax.new(:code=>"0.0_Z",:name=>"VAT"))
  end

  test "invoice check tax_per_line? method" do
    i = invoices(:i7)
    assert i.tax_per_line?('VAT')
    i.taxes.each do |tax|
      tax.code = "20.0_S"
      tax.save
    end
    assert_equal false, i.tax_per_line?('VAT')
  end

  test "recipient_emails returns a hash of email addresses" do
    i = invoices(:i7)
    assert i.recipient_emails
  end

  test 'only people with send_invoices_by_mail are included' do
    # i7 -> client_001 -> person1
    i = invoices(:i7)
    # recipient_emails contains also the client's main email
    assert_equal 2, i.recipient_emails.count
    assert_equal 'person1@example.com', i.recipient_emails.first
  end

  test 'payment_method_requirements' do
    i = invoices(:i8)
    i.payment_method_requirements
    assert_equal(0,i.export_errors.size)
    i = invoices(:i9)
    i.payment_method_requirements
    assert_equal(1,i.export_errors.size)
  end

  test 'invoice_has_taxes' do
    i = invoices(:i8)
    i.invoice_has_taxes
    assert_equal(0, i.export_errors.size)
    i = invoices(:i9)
    i.invoice_has_taxes
    assert_equal(1, i.export_errors.size)
  end

  test 'invoice payment_method' do
    i = invoices(:i8)
    assert_equal(Invoice::PAYMENT_CASH, i.payment_method)
    assert_nil i.bank_info
    i.payment_method = "#{Invoice::PAYMENT_TRANSFER}_1"
    assert i.transfer?
    assert_equal(bank_infos(:bi1),i.bank_info)
    assert i.valid?
    i.payment_method = "#{Invoice::PAYMENT_TRANSFER}_2"
    assert_false i.valid?, "bank_info is from other company"
    i.payment_method = Invoice::PAYMENT_TRANSFER
    assert i.valid?
    assert i.transfer?
    assert_nil i.bank_info
    i.payment_method = "#{Invoice::PAYMENT_DEBIT}_1"
    assert i.debit?
    assert_equal(i.bank_info,bank_infos(:bi1))
    assert i.valid?
  end

  test 'create received_invoice from facturae32' do
    assert_nil Client.find_by_taxcode "ESP6611142C"
    file    = File.new(File.join(File.dirname(__FILE__),'..','fixtures','documents','invoice_facturae32_signed.xml'))
    invoice = Invoice.create_from_xml(file,companies(:company1),User.current.name,"1234",'upload')
    client  = Client.find_by_taxcode "ESP6611142C"
    assert_not_nil client
    # client
    assert_equal "ESP6611142C", client.taxcode
    assert_equal "Ingent-lluís", client.name
    assert_equal "Melió 113", client.address
    assert_equal "Barcelona", client.province
    assert_equal "TUR", client.country
    assert_equal "", client.website
    assert_equal "ESP6611111C@b2brouter.net", client.email
    assert_equal "08720", client.postalcode
    assert_equal "Vilafranca", client.city
    assert_equal "EUR", client.currency
    assert_equal invoice.company.project, client.project
    # invoice
    assert       invoice.is_a?(ReceivedInvoice)
    assert_equal client, invoice.client
    assert_equal companies(:company1), invoice.company
    assert_equal "766", invoice.number
    assert_equal "2012-04-20", invoice.date.to_s
    assert_equal 658.00, invoice.total.to_f
    assert_equal 600.00, invoice.import.to_f
    assert_equal "2012-06-01", invoice.due_date.to_s
    assert_equal "EUR", invoice.currency
    assert_equal "facturae3.2", invoice.invoice_format
    assert_equal "upload", invoice.transport
    assert_equal "Anonymous", invoice.from
    assert_equal "1234", invoice.md5
    assert_equal 12501, invoice.original.size
    assert_equal "invoice_facturae32_signed.xml", invoice.file_name
    # invoice lines
    assert_equal 3, invoice.invoice_lines.size
    assert_equal 600.00, invoice.invoice_lines.collect {|l| l.quantity*l.price }.sum.to_f
    invoice.invoice_lines.each do |il|
      assert_equal 100, il.price
      assert_equal 1, il.taxes.size
      assert_equal 'IVA', il.taxes.first.name
    end
    assert_equal 1, invoice.invoice_lines[0].quantity
    assert_equal 2, invoice.invoice_lines[1].quantity
    assert_equal 3, invoice.invoice_lines[2].quantity
    # taxes
    assert_equal 18.0, invoice.invoice_lines[0].taxes[0].percent
    assert_equal 8.0,  invoice.invoice_lines[1].taxes[0].percent
    assert_equal 8.0,  invoice.invoice_lines[2].taxes[0].percent
    assert_equal 'S',  invoice.invoice_lines[0].taxes[0].category
    assert_equal 'S',  invoice.invoice_lines[1].taxes[0].category
    assert_equal 'S',  invoice.invoice_lines[2].taxes[0].category
  end

  test 'create issued_invoice from facturae32' do
    assert_nil Client.find_by_taxcode "ESP6611142C"
    file    = File.new(File.join(File.dirname(__FILE__),'..','fixtures','documents','invoice_facturae32_issued.xml'))
    invoice = Invoice.create_from_xml(file,companies(:company1),User.current.name,"1234",'upload')
    client  = Client.find_by_taxcode "ESP6611142C"
    assert_not_nil client
    # client
    assert_equal "ESP6611142C", client.taxcode
    assert_equal "David Copperfield", client.name
    assert_equal "Address1", client.address
    assert_equal "state", client.province
    assert_equal "ESP", client.country
    assert_equal nil, client.website
    assert_equal "suport@ingent.net", client.email
    assert_equal "08720", client.postalcode
    assert_equal "city", client.city
    assert_equal "EUR", client.currency
    assert_equal invoice.company.project, client.project
    # invoice
    assert       invoice.is_a?(IssuedInvoice)
    assert_equal client, invoice.client
    assert_equal companies(:company1), invoice.company
    assert_equal "767", invoice.number
    assert_equal "2012-04-20", invoice.date.to_s
    assert_equal 671.00, invoice.total.to_f
    assert_equal 600.00, invoice.import.to_f
    assert_equal "2012-06-01", invoice.due_date.to_s
    assert_equal "EUR", invoice.currency
    assert_equal "facturae3.2", invoice.invoice_format
    assert_equal "upload", invoice.transport
    assert_equal "Anonymous", invoice.from
    assert_equal "1234", invoice.md5
    assert_equal 7089, invoice.original.size
    assert_equal "invoice_facturae32_issued.xml", invoice.file_name
    # invoice lines
    assert_equal 3, invoice.invoice_lines.size
    assert_equal 600.00, invoice.invoice_lines.collect {|l| l.quantity*l.price }.sum.to_f
    invoice.invoice_lines.each do |il|
      assert_equal 100, il.price
      assert_equal 1, il.taxes.size
      assert_equal 'IVA', il.taxes.first.name
    end
    assert_equal 1, invoice.invoice_lines[0].quantity
    assert_equal 2, invoice.invoice_lines[1].quantity
    assert_equal 3, invoice.invoice_lines[2].quantity
    # taxes
    assert_equal 21.0, invoice.invoice_lines[0].taxes[0].percent
    assert_equal 10.0, invoice.invoice_lines[1].taxes[0].percent
    assert_equal 10.0, invoice.invoice_lines[2].taxes[0].percent
    assert_equal 'S',  invoice.invoice_lines[0].taxes[0].category
    assert_equal 'AA', invoice.invoice_lines[1].taxes[0].category
    assert_equal 'AA', invoice.invoice_lines[2].taxes[0].category
  end
end
