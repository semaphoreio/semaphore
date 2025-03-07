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
  mappings?: any[];

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
    config.mappings = configJSON.mappings || [];

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

interface GroupMapping {
  idpGroupId: string;
  semaphoreGroupId: string;
}

const App = () => {
  const config = useContext(Config);
  const [mappings, setMappings] = useState<GroupMapping[]>([
    { idpGroupId: ``, semaphoreGroupId: `` },
    { idpGroupId: ``, semaphoreGroupId: `` }
  ]);
  const [defaultRole, setDefaultRole] = useState(config.defaultRoleId || ``);

  useEffect(() => {
    // Initialize mappings from the server data if available
    if (config.mappings && config.mappings.length > 0) {
      const initialMappings = config.mappings.map((mapping: any) => ({
        idpGroupId: mapping.okta_group_id || ``,
        semaphoreGroupId: mapping.semaphore_group_id || ``
      }));
      setMappings(initialMappings);
    }
  }, [config.mappings]);

  const addMapping = () => {
    setMappings([...mappings, { idpGroupId: ``, semaphoreGroupId: `` }]);
  };

  const removeMapping = (index: number) => {
    const newMappings = [...mappings];
    newMappings.splice(index, 1);
    setMappings(newMappings);
  };

  const updateMapping = (index: number, field: keyof GroupMapping, value: string) => {
    const newMappings = [...mappings];
    newMappings[index] = { ...newMappings[index], [field]: value };
    setMappings(newMappings);
  };

  const handleSave = () => {
    // Create form data
    const formData = new FormData();
    formData.append(`default_role_id`, defaultRole);
    
    // Add mappings
    mappings.forEach((mapping, index) => {
      if (mapping.idpGroupId && mapping.semaphoreGroupId) {
        formData.append(`mappings[${index}][okta_group_id]`, mapping.idpGroupId);
        formData.append(`mappings[${index}][semaphore_group_id]`, mapping.semaphoreGroupId);
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
      <div className="mb4">
        <div className="flex mb3">
          <div className="w-50 tc">IdP group</div>
          <div className="gray f4 mh3">→</div>
          <div className="w-50 tc">Semaphore group</div>
          <div className="w3 ml3">&nbsp;</div> {/* Invisible spacer matching width of remove button */}
        </div>
        
        {mappings.map((mapping, index) => (
          <div key={index}>
            {mapping.semaphoreGroupId && !config.groups.some(g => g.id === mapping.semaphoreGroupId) && (
              <div className="f5 b mv1 red">Selected semaphore group is deleted</div>
            )}
            <div className="flex items-center mb3">
              <input 
                type="text" 
                className="form-control w-100"
                value={mapping.idpGroupId} 
                onChange={(e) => updateMapping(index, `idpGroupId`, e.currentTarget.value)}
                placeholder={`id-of-group${index + 1}`}
              />
              <div className="gray f4 mh3">→</div>
              <select
                className={`form-control w-100 ${mapping.semaphoreGroupId && !config.groups.some(g => g.id === mapping.semaphoreGroupId) ? `form-control-error` : ``}`}
                value={mapping.semaphoreGroupId}
                onChange={(e) => updateMapping(index, `semaphoreGroupId`, e.currentTarget.value)}
              >
                <option value="">Select a group</option>
                {config.groups.map(group => (
                  <option key={group.id} value={group.id}>
                    {group.name}
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