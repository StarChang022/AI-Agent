require "test_helper"

class UserMailerTest < ActionMailer::TestCase
  test "註冊確認信：HTML 與純文字的連結都指向前端確認頁，並帶 token" do
    mail = UserMailer.signup_verification("new@example.com", "abc-123")

    assert_equal [ "new@example.com" ], mail.to
    expected = "#{Rails.configuration.frontend_base_url}/admin/signup/confirm?token=abc-123"
    assert_includes mail.html_part.body.decoded, %(href="#{expected}")
    assert_includes mail.text_part.body.decoded, expected
    [ mail.html_part, mail.text_part ].each do |part|
      assert_not_includes part.body.decoded, "/signup/complete"
    end
  end

  test "申請註冊寄出的信，連結 token 可以完成註冊" do
    assert_emails 1 do
      SignupToken.generate_for(email: "new@example.com", password: "password123",
        company_type: "limited", company_name: "新公司").last.then do |raw|
        UserMailer.signup_verification("new@example.com", raw).deliver_now
      end
    end

    link = URI(ActionMailer::Base.deliveries.last.text_part.body.decoded[%r{https?://\S+}])
    assert_equal "/admin/signup/confirm", link.path
    token = Rack::Utils.parse_query(link.query).fetch("token")
    assert_not_nil SignupToken.find_valid_by_raw(token)
  end
end
