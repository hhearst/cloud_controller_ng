require 'spec_helper'

module VCAP::CloudController
  describe TcpRouteValidator do
    let(:validator) { TcpRouteValidator.new(routing_api_client, domain_guid, port) }
    let(:routing_api_client) { double('routing_api', router_group: router_group) }
    let(:router_group) { double(:router_group, type: router_group_type, guid: router_group_guid) }
    let(:router_group_type) { 'tcp' }
    let(:router_group_guid) { 'router-group-guid' }
    let(:domain_guid) { domain.guid }
    let(:domain) { SharedDomain.make(router_group_guid: router_group_guid) }
    let(:port) { 8080 }

    context 'when non-existent domain is specified' do
      let(:domain_guid) { 'non-existent-domain' }

      it 'raises a DomainInvalid error' do
        expect { validator.validate }.
            to raise_error(TcpRouteValidator::DomainInvalid, 'Domain with guid non-existent-domain does not exist')
      end
    end

    context 'when creating a route with a null port value' do
      let(:port) { nil }

      context 'with a tcp domain' do
        let(:domain) { SharedDomain.make(router_group_guid: router_group_guid) }

        it 'raises a RouteInvalid error' do
          expect { validator.validate }.
              to raise_error(TcpRouteValidator::RouteInvalid, 'Router groups are only supported for TCP routes.')
        end
      end
    end

    context 'when creating a route with a port value that is not null' do
      context 'with a domain without a router_group_guid' do
        let(:domain) { SharedDomain.make(router_group_guid: nil) }

        it 'raises a RouteInvalid error' do
          expect { validator.validate }.
              to raise_error(TcpRouteValidator::RouteInvalid, 'Port is supported for domains of TCP router groups only.')
        end
      end

      context 'with a domain with a router_group_guid and type tcp' do
        it 'does not raise an error' do
          expect { validator.validate }.not_to raise_error
        end

        context 'with an invalid port' do
          let(:port) { 0 }

          it 'raises a RouteInvalid error' do
            expect { validator.validate }.
                to raise_error(TcpRouteValidator::RouteInvalid, 'Port must be greater than 0 and less than 65536.')
          end
        end

        context 'when port is already taken in the same router group' do
          before do
            domain_in_same_router_group = SharedDomain.make(router_group_guid: router_group_guid)
            Route.make(domain: domain_in_same_router_group, port: port)
          end

          it 'raises a RoutePortTaken error' do
            error_message = "Port #{port} is not available on this domain's router group. " \
                'Try a different port, request an random port, or ' \
                'use a domain of a different router group.'

            expect { validator.validate }.
                to raise_error(TcpRouteValidator::RoutePortTaken, error_message)
          end
        end

        context 'when port is already taken in a different router group' do
          before do
            domain_in_different_router_group = SharedDomain.make(router_group_guid: 'different-router-group')
            Route.make(domain: domain_in_different_router_group, port: port)
          end

          it 'does not raise an error' do
            expect { validator.validate }.not_to raise_error
          end
        end
      end

      context 'with a domain without a router_group_guid' do
        let(:domain) { SharedDomain.make(router_group_guid: nil) }

        it 'rejects the request with a RouteInvalid error' do
          expect { validator.validate }.
              to raise_error(TcpRouteValidator::RouteInvalid, 'Port is supported for domains of TCP router groups only.')
        end
      end

      context 'with a domain with a router_group_guid of type other than tcp' do
        let(:router_group_type) { 'http' }

        it 'rejects the request with a RouteInvalid error' do
          expect { validator.validate }.
              to raise_error(TcpRouteValidator::RouteInvalid, 'Port is supported for domains of TCP router groups only.')
        end
      end
    end

    context 'when the routing api client raises a UaaUnavailable error' do
      before do
        allow(routing_api_client).to receive(:router_group).
                                         and_raise(RoutingApi::Client::UaaUnavailable)
      end

      it 'does not rescue the exception' do
        expect { validator.validate }.
            to raise_error(RoutingApi::Client::UaaUnavailable)
      end
    end

    context 'when the routing api client raises a RoutingApiUnavailable error' do
      before do
        allow(routing_api_client).to receive(:router_group).
                                         and_raise(RoutingApi::Client::RoutingApiUnavailable)
      end

      it 'does not rescue the exception' do
        expect { validator.validate }.
            to raise_error(RoutingApi::Client::RoutingApiUnavailable)
      end
    end
  end
end
