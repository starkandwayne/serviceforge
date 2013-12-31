require 'spec_helper'

describe Bosh::ReleaseTemplates do
  describe "#build" do
    subject {
      Bosh::ReleaseTemplates.build({
        "base_path" => File.join(Rails.root, "releases", "etcd", "templates"),
        "templates" => [
          "etcd-deployment.yml",
          "etcd-jobs.yml",
          "etcd-properties.yml",
          "etcd-infrastructure-warden.yml"
        ],
        "stub" => "etcd-stub-spiff.yml"
      })
    }

    it { expect(File.basename(subject.base_path)).to eq("templates") }
    it { expect(subject.templates).to be_instance_of(Array) }

    it do
      first_template_path = subject.template_paths.first
      expect(File.exists?(first_template_path)).to be_true
    end

    it { expect(File.exists?(subject.stub_path)).to be_true }
  end
end
