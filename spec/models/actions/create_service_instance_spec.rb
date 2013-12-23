require 'spec_helper'

# forced loading to avoid 'not a defined constant' rspec-fire issue
require 'bosh_director_client'
require 'generators/generate_deployment_stub'
require 'generators/generate_deployment_manifest'

describe Actions::CreateServiceInstance do
  let(:stub_generator)        { instance_double("Generators::GenerateDeploymentStub") }
  let(:manifest_generator)    { instance_double("Generators::GenerateDeploymentManifest") }
  let(:service)               { instance_double("Service") }
  let(:service_plan)          { instance_double("Plan") }
  let(:service_id)            { 'service-id-1' }
  let(:service_instance_id)   { 'service-instance-id-1' }
  let(:deployment_stub)       { "---\nname: something" }
  let(:service_plan_stub)     { "---\njobs:\n  - name: etc\n  - instances: 2" }
  let(:director_uuid)         { "director-uuid" }
  let(:deployment_name)       { "deployment-name" }
  let(:deployment_manifest)   { "---\nname: something\ndirector_uuid: director-uuid" }
  let(:bosh_director_client)  { instance_double("BoshDirectorClient") }
  let(:bosh_deploy_task_id)   { 123 }

  before do
    begin
      $etcd.delete("/actions", recursive: true)
    rescue Net::HTTPServerException
    end
  end


  it "has lifecycle" do
    uuid_klass = class_double("UUIDTools::UUID").as_stubbed_const
    uuid_klass.should_receive(:timestamp_create).and_return(deployment_name)

    action = Actions::CreateServiceInstance.new(service_id: service_id, service_instance_id: service_instance_id)
    action.save

    ##
    ## Test the etcd entry
    ##
    data = JSON.parse($etcd.get("/actions/create_service_instances/#{service_instance_id}").value)
    expect(data).to eq({
      'service_id' => service_id,
      'service_instance_id' => service_instance_id,
      'deployment_name' => deployment_name,
      'bosh_task_id' => nil
    })

    ##
    ## Generate deployment manifest
    ##
    service_klass = class_double('Service').as_stubbed_const
    service_klass.should_receive(:find_by_id).and_return(service)
    service.should_receive(:bosh).and_return({'director_uuid' => director_uuid})
    service.should_receive(:find_plan_by_id).and_return(service_plan)
    service_plan.should_receive(:deployment_stub).and_return(service_plan_stub)

    gds_klass = class_double('Generators::GenerateDeploymentStub').as_stubbed_const
    gds_klass.should_receive(:new).with({bosh_director_uuid: director_uuid, deployment_name: deployment_name}).and_return(stub_generator)
    stub_generator.should_receive(:generate_stub).and_return(deployment_stub)

    gdm_klass = class_double("Generators::GenerateDeploymentManifest").as_stubbed_const
    gdm_klass.should_receive(:new).with({deployment_stub: deployment_stub, service_plan_stub: service_plan_stub}).and_return(manifest_generator)
    manifest_generator.should_receive(:generate_manifest).and_return(deployment_manifest)

    action.should_receive(:bosh_director_client).and_return(bosh_director_client)
    bosh_director_client.should_receive(:deploy_and_return_task_id).with(deployment_manifest).and_return(bosh_deploy_task_id)

    action.perform

    ##
    ## Test the etcd entry
    ##
    data = JSON.parse($etcd.get("/actions/create_service_instances/#{service_instance_id}").value)
    expect(data).to eq({
      'service_id' => service_id,
      'service_instance_id' => service_instance_id,
      'deployment_name' => deployment_name,
      'bosh_task_id' => bosh_deploy_task_id
    })


    action.destroy
    expect{ $etcd.get("/actions/create_service_instances/#{service_instance_id}") }.to raise_error(Net::HTTPServerException)
  end
end
