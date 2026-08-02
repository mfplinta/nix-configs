{
  sysModule =
    { config, lib, ... }:
    let
      inherit (lib)
        all
        attrValues
        concatLists
        concatMapStringsSep
        filter
        filterAttrs
        hasInfix
        hasPrefix
        mapAttrsToList
        mkIf
        mkOption
        optional
        types
        unique
        ;

      containers = config.virtualisation.quadlet.containers;
      statefulContainers = filterAttrs (_: container: container.stateMounts.mounts != { }) containers;
      mountsFor =
        service: container:
        let
          state = container.stateMounts;
          defaultGid = if state.gid == null then state.uid else state.gid;
        in
        mapAttrsToList (
          hostPath: mount:
          let
            uid = if mount.uid == null then state.uid else mount.uid;
          in
          {
            inherit service hostPath uid;
            containerPath = mount.containerPath;
            gid =
              if mount.gid != null then
                mount.gid
              else if mount.uid != null then
                mount.uid
              else
                defaultGid;
            mode = if mount.mode == null then state.mode else mount.mode;
            readOnly = mount.readOnly;
            enforceRecursiveOwnership =
              if mount.enforceRecursiveOwnership == null then
                state.enforceRecursiveOwnership
              else
                mount.enforceRecursiveOwnership;
          }
        ) state.mounts;
      mounts = concatLists (mapAttrsToList mountsFor statefulContainers);
      volumeFor =
        mount:
        "${mount.hostPath}:${mount.containerPath}:${
          concatMapStringsSep "," (value: value) ((optional mount.readOnly "ro") ++ [ "idmap" ])
        }";
      declaredPersistentVolumes = concatLists (
        mapAttrsToList (
          _: container: filter hasPersistentSource (container.containerConfig.volumes or [ ])
        ) containers
      );
      managedPersistentVolumes = map volumeFor mounts;
      hasPersistentSource = volume: hasPrefix "/persist/" volume;
    in
    {
      options.virtualisation.quadlet.containers = mkOption {
        type = types.attrsOf (
          types.submodule (
            { config, name, ... }:
            {
              options.stateMounts = {
                uid = mkOption {
                  type = types.ints.unsigned;
                  default = 0;
                  description = "Default stable owner UID for this container's state.";
                };

                gid = mkOption {
                  type = types.nullOr types.ints.unsigned;
                  default = null;
                  description = "Default stable owner GID; defaults to the UID.";
                };

                mode = mkOption {
                  type = types.strMatching "0[0-7]{3}";
                  default = "0700";
                  description = "Default mode enforced on state mount roots.";
                };

                enforceRecursiveOwnership = mkOption {
                  type = types.bool;
                  default = true;
                  description = "Recursively enforce stable ownership without changing child modes.";
                };

                mounts = mkOption {
                  default = { };
                  description = "Persistent bind mounts keyed by their absolute host paths.";
                  type = types.attrsOf (
                    types.submodule {
                      options = {
                        containerPath = mkOption {
                          type = types.str;
                          description = "Absolute mount point inside the container.";
                        };

                        uid = mkOption {
                          type = types.nullOr types.ints.unsigned;
                          default = null;
                          description = "Owner UID override for this mount.";
                        };

                        gid = mkOption {
                          type = types.nullOr types.ints.unsigned;
                          default = null;
                          description = "Owner GID override for this mount.";
                        };

                        mode = mkOption {
                          type = types.nullOr (types.strMatching "0[0-7]{3}");
                          default = null;
                          description = "Mode override for this mount root.";
                        };

                        readOnly = mkOption {
                          type = types.bool;
                          default = false;
                          description = "Mount the directory read-only inside the container.";
                        };

                        enforceRecursiveOwnership = mkOption {
                          type = types.nullOr types.bool;
                          default = null;
                          description = "Recursive ownership override for this mount.";
                        };
                      };
                    }
                  );
                };
              };

              config.containerConfig.volumes = mkIf (config.stateMounts.mounts != { }) (
                map volumeFor (mountsFor name config)
              );
            }
          )
        );
      };

      config = mkIf (mounts != [ ]) {
        assertions = [
          {
            assertion = all (
              mount: hasPrefix "/persist/" mount.hostPath && hasPrefix "/" mount.containerPath
            ) mounts;
            message = "Quadlet state must use an absolute /persist host path and absolute container path.";
          }
          {
            assertion = all (mount: mount.uid <= 65535 && mount.gid <= 65535) mounts;
            message = "Quadlet state IDs must fit in the container user namespace.";
          }
          {
            assertion = builtins.length mounts == builtins.length (unique (map (mount: mount.hostPath) mounts));
            message = "Each Quadlet state directory must have exactly one ownership declaration.";
          }
          {
            assertion = all (
              serviceMounts:
              builtins.length serviceMounts
              == builtins.length (unique (map (mount: mount.containerPath) serviceMounts))
            ) (attrValues (builtins.groupBy (mount: mount.service) mounts));
            message = "A Quadlet service cannot mount multiple state directories at the same container path.";
          }
          {
            assertion = all (mount: (containers.${mount.service}.containerConfig.image or null) != null) mounts;
            message = "Every Quadlet state mount must belong to a container with a declared image.";
          }
          {
            assertion = all (volume: !(hasInfix ":U" volume || hasInfix ",U" volume)) declaredPersistentVolumes;
            message = "Persistent Quadlet mounts must use idmap, not ownership-mutating :U.";
          }
          {
            assertion =
              builtins.sort builtins.lessThan declaredPersistentVolumes
              == builtins.sort builtins.lessThan managedPersistentVolumes;
            message = "Every Quadlet /persist bind mount must be declared through its container's stateMounts.";
          }
        ];

        systemd.tmpfiles.rules = concatLists (
          map (
            mount:
            [ "d ${mount.hostPath} ${mount.mode} ${toString mount.uid} ${toString mount.gid} -" ]
            ++ optional mount.enforceRecursiveOwnership "Z ${mount.hostPath} - ${toString mount.uid} ${toString mount.gid} -"
          ) mounts
        );
      };
    };
}
