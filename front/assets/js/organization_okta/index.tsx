import { render, createContext } from "preact";
import { useState, useContext, useEffect } from "preact/hooks";

// eslint-disable-next-line @typescript-eslint/ban-ts-comment
// @ts-ignore
import { Notice } from "js/notice";

interface group {
  id: string;
  name: string;
}

interface role {
  id: string;
  name: string;
}

export class State {
  groups: group[];
  roles: role[];
  defaultRoleId: string;
  saveUrl: string;
  cancelUrl: string;
  groupMapping: any[];
  roleMapping: any[];

  static fromJSON(configJSON: any): State {
    const config = State.default();

    config.groups = configJSON.groups.map((group: any) => {
      return {
        id: group.id,
        name: group.name,
      };
    });

    config.roles = configJSON.roles.map((role: any) => {
      return {
        id: role.id,
        name: role.name,
      };
    });

    config.saveUrl = configJSON.saveUrl;
    config.cancelUrl = configJSON.cancelUrl;
    config.defaultRoleId = configJSON.defaultRoleId;
    config.groupMapping = configJSON.group_mapping || [];
    config.roleMapping = configJSON.role_mapping || [];

    return config;
  }

  static default(): State {
    return new State();
  }
}

export function OrganizationOktaGroupMappingApp({ config, dom }: { config: any, dom: HTMLElement, }) {
  render(
    <Config.Provider value={State.fromJSON(config)}>
      <App/>
    </Config.Provider>,
    dom,
  );
}

interface Mapping {
  idpId: string;
  semaphoreId: string;
}

interface MappingSectionProps {
  mappings: Mapping[];
  setMappings: (mappings: Mapping[]) => void;
  options: { id: string, name: string, }[];
  leftLabel: string;
  rightLabel: string;
  leftPlaceholder: (index: number) => string;
  rightErrorCondition: (id: string) => boolean;
}

const MappingSection = ({
  mappings,
  setMappings,
  options,
  leftLabel,
  rightLabel,
  leftPlaceholder,
  rightErrorCondition,
}: MappingSectionProps) => {
  const addMapping = () => {
    setMappings([...mappings, { idpId: ``, semaphoreId: `` }]);
  };

  const removeMapping = (index: number) => {
    const newMappings = [...mappings];
    newMappings.splice(index, 1);
    setMappings(newMappings);
  };

  const updateMapping = (index: number, field: keyof Mapping, value: string) => {
    const newMappings = [...mappings];
    newMappings[index] = { ...newMappings[index], [field]: value };
    setMappings(newMappings);
  };

  return (
    <div className="mb4">
      <div className="flex mb3">
        <div className="w-50 tc">{leftLabel}</div>
        <div className="gray f4 mh3">→</div>
        <div className="w-50 tc">{rightLabel}</div>
        <div className="w3 ml3">&nbsp;</div> {/* Invisible spacer matching width of remove button */}
      </div>
      
      {mappings.map((mapping, index) => (
        <div key={index}>
          {mapping.semaphoreId && rightErrorCondition(mapping.semaphoreId) && (
            <div className="f5 b mv1 red">Selected {rightLabel.toLowerCase()} is deleted</div>
          )}
          <div className="flex items-center mb3">
            <input 
              type="text" 
              className="form-control w-100"
              value={mapping.idpId} 
              onChange={(e) => updateMapping(index, `idpId`, e.currentTarget.value)}
              placeholder={leftPlaceholder(index)}
            />
            <div className="gray f4 mh3">→</div>
            <select
              className={`form-control w-100 ${mapping.semaphoreId && rightErrorCondition(mapping.semaphoreId) ? `form-control-error` : ``}`}
              value={mapping.semaphoreId}
              onChange={(e) => updateMapping(index, `semaphoreId`, e.currentTarget.value)}
            >
              <option value="">Select a {rightLabel.toLowerCase()}</option>
              {options.map(item => (
                <option key={item.id} value={item.id}>
                  {item.name}
                </option>
              ))}
            </select>
            <button 
              className="btn btn-secondary w3 ml3" 
              name="remove-btn"
              onClick={() => removeMapping(index)}
            >
              ×
            </button>
          </div>
        </div>
      ))}
      
      <div className="mt2">
        <button 
          className="btn bn br2 ph3 pv2 pointer fw6 blue ba b--blue bg-white" 
          onClick={addMapping}
        >
          Add
        </button>
      </div>
    </div>
  );
};

const App = () => {
  const config = useContext(Config);
  const [groupMappings, setGroupMappings] = useState<Mapping[]>([
    { idpId: ``, semaphoreId: `` },
    { idpId: ``, semaphoreId: `` }
  ]);
  
  const [roleMappings, setRoleMappings] = useState<Mapping[]>([
    { idpId: ``, semaphoreId: `` },
    { idpId: ``, semaphoreId: `` }
  ]);
  
  const memberRole = config.roles.find(role => role.name === `Member`);
  const firstRole = config.roles.length > 0 ? config.roles[0].id : ``;
  const [defaultRole, setDefaultRole] = useState(config.defaultRoleId || memberRole?.id || firstRole || ``);

  useEffect(() => {
    if (config.groupMapping && config.groupMapping.length > 0) {
      const initialGroupMappings = config.groupMapping.map((mapping: any) => ({
        idpId: mapping.okta_id || mapping.okta_group_id || ``,
        semaphoreId: mapping.semaphore_id || mapping.semaphore_group_id || ``
      }));
      setGroupMappings(initialGroupMappings);
    }
    
    if (config.roleMapping && config.roleMapping.length > 0) {
      const initialRoleMappings = config.roleMapping.map((mapping: any) => ({
        idpId: mapping.okta_id || mapping.okta_group_id || ``,
        semaphoreId: mapping.semaphore_id || mapping.semaphore_role_id || ``
      }));
      setRoleMappings(initialRoleMappings);
    }
  }, [config.groupMapping, config.roleMapping]);

  const handleSave = () => {
    // Create form data
    const formData = new FormData();
    formData.append(`default_role_id`, defaultRole);
    
    // Add group mappings
    groupMappings.forEach((mapping, index) => {
      if (mapping.idpId && mapping.semaphoreId) {
        formData.append(`group_mapping[${index}][okta_id]`, mapping.idpId);
        formData.append(`group_mapping[${index}][semaphore_id]`, mapping.semaphoreId);
      }
    });
    
    // Add role mappings
    roleMappings.forEach((mapping, index) => {
      if (mapping.idpId && mapping.semaphoreId) {
        formData.append(`role_mapping[${index}][okta_id]`, mapping.idpId);
        formData.append(`role_mapping[${index}][semaphore_id]`, mapping.semaphoreId);
      }
    });
    
    // Submit the form
    fetch(config.saveUrl, {
      method: `POST`,
      body: formData,
      headers: {
        'X-CSRF-Token': document.querySelector(`meta[name="csrf-token"]`)?.getAttribute(`content`) || ``,
      },
    })
      .then(response => {
        if (response.ok) {
          window.location.href = config.cancelUrl;
        } else {
          Notice.error(`Failed to save mappings`);
        }
      })
      .catch(error => {
        Notice.error(`Error saving mappings: ${error instanceof Error ? error.message : String(error)}`);
      });
  };

  return (
    <div className="mw7 center">
      <h4 className="mb4">Group Mapping</h4>
      <MappingSection
        mappings={groupMappings}
        setMappings={setGroupMappings}
        options={config.groups}
        leftLabel="IdP group"
        rightLabel="Semaphore group"
        leftPlaceholder={(index) => `id-of-group-${index + 1}`}
        rightErrorCondition={(id) => !config.groups.some(g => g.id === id)}
      />
      
      <hr className="bb b--light-gray mv4"/>
      
      <h4 className="mb4">Role Mapping</h4>
      <MappingSection
        mappings={roleMappings}
        setMappings={setRoleMappings}
        options={config.roles}
        leftLabel="IdP role"
        rightLabel="Semaphore role"
        leftPlaceholder={(index) => `id-of-role-${index + 1}`}
        rightErrorCondition={(id) => !config.roles.some(r => r.id === id)}
      />

      <hr className="bb b--light-gray mv4"/>

      <div className="flex items-center mb4">
        <div className="nowrap w4 mr3">Default role:</div>
        <select 
          className="form-control w-100"
          value={defaultRole}
          onChange={(e) => setDefaultRole(e.currentTarget.value)}
        >
          {config.roles.map(role => (
            <option key={role.id} value={role.id}>
              {role.name}
            </option>
          ))}
        </select>
      </div>

      <div className="flex">
        <button 
          className="btn btn-primary mr3" 
          onClick={handleSave}
        >
          Save
        </button>
        <button 
          className="btn btn-secondary" 
          onClick={() => window.location.href = config.cancelUrl}
        >
          Cancel
        </button>
      </div>
    </div>
  );
};

export const Config = createContext<State>(new State());