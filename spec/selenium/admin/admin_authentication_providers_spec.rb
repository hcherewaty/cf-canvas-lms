# frozen_string_literal: true

#
# Copyright (C) 2012 - present Instructure, Inc.
#
# This file is part of Canvas.
#
# Canvas is free software: you can redistribute it and/or modify it under
# the terms of the GNU Affero General Public License as published by the Free
# Software Foundation, version 3 of the License.
#
# Canvas is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
# A PARTICULAR PURPOSE. See the GNU Affero General Public License for more
# details.
#
# You should have received a copy of the GNU Affero General Public License along
# with this program. If not, see <http://www.gnu.org/licenses/>.

require_relative "../common"

describe "Authentication Providers" do
  include_context "in-process server selenium tests"

  before { admin_logged_in }

  context "LDAP" do
    before do
      Account.default.authentication_providers.create!({
                                                         auth_host: "blah.blah",
                                                         auth_over_tls: true,
                                                         auth_port: "123",
                                                         auth_type: "ldap",
                                                       })
    end

    context "Server errors" do
      it "shows the error message generated by the server" do
        get "/accounts/#{Account.default.id}/authentication_providers"
        f(".test_ldap_link").click
        wait_for_ajaximations
        expect(f("#ldap_connection_help .server_error").text).to eq "Unknown host: blah.blah"
      end
    end

    context "TLS certificate verification" do
      context "with the feature flag disabled" do
        before { Account.default.disable_feature!(:verify_ldap_certs) }

        it "allows the opt-in checkbox to be toggled" do
          get "/accounts/#{Account.default.id}/authentication_providers"
          expect(f("#verify_tls_cert_opt_in_ldap")).to be_enabled
        end

        context "with the dated help text enabled" do
          before do
            Setting.set("ldap_validate_tls_cert_help_text_format", "dated")
            Setting.set("ldap_validate_tls_cert_enforcement_date", 1.week.from_now.to_i)
          end

          it "shows the correct help text" do
            get "/accounts/#{Account.default.id}/authentication_providers"
            element = f(".ldap-verify-tls-cert-opt-in-help-text")
            expect(element.text).to start_with("TLS certificate verification will be required on")
            expect(element.text).to end_with(", but you may enable it early to ensure your LDAP server is compliant.")
          end

          context "with a date not specified" do
            before { Setting.set("ldap_validate_tls_cert_enforcement_date", nil) }

            it "does not show help text" do
              get "/accounts/#{Account.default.id}/authentication_providers"
              expect(element_exists?(".ldap-verify-tls-cert-opt-in-help-text")).to be_falsey
            end
          end
        end

        context "with the undated help text enabled" do
          before { Setting.set("ldap_validate_tls_cert_help_text_format", "undated") }

          it "shows the correct help text" do
            get "/accounts/#{Account.default.id}/authentication_providers"
            expect(f(".ldap-verify-tls-cert-opt-in-help-text").text).to eq("TLS certificate verification will be required soon, but you may enable it early to ensure your LDAP server is compliant.")
          end
        end

        context "with no help text enabled" do
          before { Setting.set("ldap_validate_tls_cert_help_text_format", nil) }

          it "does not show the help text" do
            get "/accounts/#{Account.default.id}/authentication_providers"
            expect(element_exists?(".ldap-verify-tls-cert-opt-in-help-text")).to be_falsey
          end
        end
      end

      context "with the feature flag enabled" do
        before { Account.default.enable_feature!(:verify_ldap_certs) }

        it "does not allow the opt-in checkbox to be toggled" do
          get "/accounts/#{Account.default.id}/authentication_providers"
          expect(f("#verify_tls_cert_opt_in_ldap")).not_to be_enabled
        end

        context "with the dated help text enabled" do
          before do
            Setting.set("ldap_validate_tls_cert_help_text_format", "dated")
            Setting.set("ldap_validate_tls_cert_enforcement_date", 1.week.from_now.to_i)
          end

          it "does not show the help text" do
            get "/accounts/#{Account.default.id}/authentication_providers"
            expect(element_exists?(".ldap-verify-tls-cert-opt-in-help-text")).to be_falsey
          end
        end

        context "with the undated help text enabled" do
          before { Setting.set("ldap_validate_tls_cert_help_text_format", "undated") }

          it "does not show the help text" do
            get "/accounts/#{Account.default.id}/authentication_providers"
            expect(element_exists?(".ldap-verify-tls-cert-opt-in-help-text")).to be_falsey
          end
        end

        context "with no help text enabled" do
          before { Setting.set("ldap_validate_tls_cert_help_text_format", nil) }

          it "does not show the help text" do
            get "/accounts/#{Account.default.id}/authentication_providers"
            expect(element_exists?(".ldap-verify-tls-cert-opt-in-help-text")).to be_falsey
          end
        end
      end
    end
  end
end