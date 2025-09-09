import { useState } from "preact/hooks";
import { Box } from "js/toolbox";
import { CreateEnvironmentData } from "../types";

interface EnvironmentFormProps {
  onCreate: (data: CreateEnvironmentData) => Promise<void>;
  onCancel: () => void;
  projects: Array<{ id: string, name: string, }>;
  initialData?: Partial<CreateEnvironmentData>;
  formType?: `create` | `edit`;
}

export const EnvironmentForm = ({
  formType,
  onCreate,
  onCancel,
  projects,
  initialData
}: EnvironmentFormProps) => {
  const [formData, setFormData] = useState<CreateEnvironmentData>({
    name: initialData?.name || ``,
    description: initialData?.description || ``,
    max_instances: initialData?.max_instances || 1,
  });
  const [errors, setErrors] = useState<Record<string, string>>({});
  const [isSubmitting, setIsSubmitting] = useState(false);

  const handleChange = (field: keyof CreateEnvironmentData, value: any) => {
    setFormData(prev => ({ ...prev, [field]: value }));
    // Clear error for this field
    if (errors[field]) {
      setErrors(prev => ({ ...prev, [field]: `` }));
    }
  };

  const validate = (): boolean => {
    const newErrors: Record<string, string> = {};

    if (!formData.name.trim()) {
      newErrors.name = `Name is required`;
    } else if (formData.name.length > 100) {
      newErrors.name = `Name must be less than 100 characters`;
    }

    if (formData.max_instances < 1) {
      newErrors.max_instances = `Must have at least 1 instance`;
    } else if (formData.max_instances > 100) {
      newErrors.max_instances = `Maximum 100 instances allowed`;
    }

    setErrors(newErrors);
    return Object.keys(newErrors).length === 0;
  };

  const handleSubmit = async (e: Event) => {
    e.preventDefault();

    if (!validate()) return;

    setIsSubmitting(true);
    try {
      await onCreate(formData);
    } catch (error) {
      console.error(`Failed to create environment:`, error);
    } finally {
      setIsSubmitting(false);
    }
    return;
  };

  const SubmitButton = () => {
    return (
      <button
        type="submit"
        className="btn btn-primary"
        disabled={isSubmitting}
      >
        {formType === `edit` && (isSubmitting ? `Saving...` : `Save Changes`)}
        {formType === `create` && (isSubmitting ? `Creating...` : `Create Environment`)}
      </button>
    );
  };

  return (
    <div className="bg-white br3 ba b--black-10">
      <form onSubmit={handleSubmit}>
        <div className="pa4">
          <h2 className="f3 mb4">Basic Configuration</h2>

          <div className="mb2">
            <label className="db fw6 lh-copy f6 mb2" htmlFor="name">
              Name: <span className="red">*</span>
            </label>
            <input
              type="text"
              id="name"
              className={`form-control pa2 db w-100 ${errors.name ? `b--red` : ``}`}
              value={formData.name}
              onChange={(e) => handleChange(`name`, (e.target as HTMLInputElement).value)}
              placeholder="e.g., Development Environment"
              disabled={isSubmitting}
            />
            {errors.name && (
              <small className="red db mt1">{errors.name}</small>
            )}
          </div>

          <div className="mb2">
            <label className="db fw6 lh-copy f6 mb2" htmlFor="description">
              Description:
            </label>
            <textarea
              id="description"
              className="form-control pa2 db w-100"
              rows={3}
              value={formData.description}
              onChange={(e) => handleChange(`description`, (e.target as HTMLTextAreaElement).value)}
              placeholder="Brief description of this environment type"
              disabled={isSubmitting}
            />
          </div>

          <div className="mb2">
            <label className="db fw6 lh-copy f6 mb2" htmlFor="max_instances">
              Max number of instances: <span className="red">*</span>
            </label>
            <input
              type="number"
              id="max_instances"
              className={`form-control pa2 db w-30 ${errors.max_instances ? `b--red` : ``}`}
              value={formData.max_instances}
              onChange={(e) => handleChange(`max_instances`, parseInt((e.target as HTMLInputElement).value) || 1)}
              min="1"
              max="100"
              disabled={isSubmitting}
            />
            {errors.max_instances && (
              <small className="red db mt1">{errors.max_instances}</small>
            )}
          </div>
        </div>

        <div className="bt b--black-10 pa4">
          <h2 className="f3 mb3">Pipeline configuration</h2>
          <Box type="info" className="mb4">
            <p className="ma0 f6">
              Configure pipelines that will be used to provision, deprovision, and deploy to instances of this environment type.
              This will include deployment scripts, resource allocation, and networking configuration.
            </p>
          </Box>

          <div className="mb3 flex flex-row flex-1 w-100">
            <div className="flex items-center justify-between">
              <label className="fw6 lh-copy f5 gray">
                Provisioning
              </label>
              <select className="form-control" disabled={true} style="flex-grow: 1;">
                <option>Select provisioning project...</option>
              </select>
              <input type="text" className="form-control" value="pipeline.yml" style="flex-grow: 1;"/>
            </div>
          </div>
        </div>

        <div className="bt b--black-10 pa4">
          <h2 className="f3 mb3">Access Control</h2>
          <Box type="info" className="mb4">
            <p className="ma0 f6">
              Define which projects and users can provision and deploy to this environment.
            </p>
          </Box>

          <div className="mb3">
            <label className="db fw6 lh-copy f6 mb2 gray">
              Projects that can deploy to this environment
            </label>
            <select className="ba b--black-20 pa2 db w-100 bg-light-gray" disabled={true}>
              <option>Select projects...</option>
            </select>
          </div>

          <div className="mb3">
            <label className="db fw6 lh-copy f6 mb2 gray">
              Who can provision this environment
            </label>
            <select className="ba b--black-20 pa2 db w-100 bg-light-gray" disabled={true}>
              <option>Select users or teams...</option>
            </select>
          </div>

          <div className="mb3">
            <label className="db fw6 lh-copy f6 mb2 gray">
              Who can deploy to this environment
            </label>
            <select className="ba b--black-20 pa2 db w-100 bg-light-gray" disabled={true}>
              <option>Select users or teams...</option>
            </select>
          </div>
        </div>

        <div className="bt b--black-10 pa4">
          <h2 className="f3 mb3">Ephemeral Secrets</h2>
          <Box type="info" className="mb4">
            <p className="ma0 f6">
              Define secrets that will be passed between provisioning and deployment pipelines.
            </p>
          </Box>

          <div className="mb3">
            <label className="db fw6 lh-copy f6 mb2 gray">
              Environment Secrets
            </label>
            <SecretList/>
          </div>
        </div>

        <div className="bt b--black-10 pa4 flex justify-end">
          <button
            type="button"
            className="btn btn-secondary mr3"
            onClick={onCancel}
            disabled={isSubmitting}
          >
            Cancel
          </button>
          <SubmitButton/>
        </div>
      </form>
    </div>
  );
};

const Secret = ({ name, description }: { name: string, description: string, }) => {
  return (
    <div className="flex mb2">
      <div className="pa2 bg-washed-gray br2 mr2 w-30">
        <b>{name}</b>
      </div>
      <div className="pa2 br2" style="flex-grow: 2;">{description}</div>
    </div>
  );
};


const NewSecret = () => {
  return (
    <div className="flex mb2">
      <div className="pa2 bg-washed-gray br2 mr2 w-30">
        <input type="text" className="form-control w-100" placeholder="Secret name"/>
      </div>

      <div className="pa2 br2" style="flex-grow: 2;">
        <input type="text" className="form-control w-100" placeholder="Secret description"/>
      </div>
    </div>
  );
};

const SecretList = () => {
  return <div className="flex flex-column">
    <Secret name="DB_PASSWORD" description="Password for the database used by the application."/>
    <Secret name="API_KEY" description="API key for third-party service integration."/>
    <Secret name="REDIS_URL" description="Connection URL for the Redis instance."/>
    <Secret name="AWS_SECRET_ACCESS_KEY" description="Secret access key for AWS services."/>
    <Secret name="AWS_ACCESS_KEY_ID" description="Access key ID for AWS services."/>
    <Secret name="INSTANCE_URL" description="URL where application running at the instance can be accessed."/>
    <Secret name="K8S_API_TOKEN" description="API token used to connect to running k8s cluster via kubectl."/>
    <NewSecret/>
  </div>;
};
