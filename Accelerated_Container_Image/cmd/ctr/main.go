/*
   Copyright The Accelerated Container Image Authors

   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at

       http://www.apache.org/licenses/LICENSE-2.0

   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.
*/

package main

import (
	"fmt"
	"os"
	"os/exec"

	"github.com/containerd/containerd/v2/cmd/ctr/app"
	"github.com/urfave/cli/v2"
)

var pluginCmds = []*cli.Command{
	rpullCommand,
	convertCommand,
	recordTraceCommand,
}

func main() {
	app := app.New()
	app.Commands = append(app.Commands, pluginCmds...)

	// Hook: Hijack 'images push' to support auto-conversion
	injectPushHook(app)

	if err := app.Run(os.Args); err != nil {
		fmt.Fprintf(os.Stderr, "ctr: %s\n", err)
		os.Exit(1)
	}
}

// injectPushHook traverses the command tree to find 'images push' and wraps its action
func injectPushHook(app *cli.App) {
	for _, cmd := range app.Commands {
		if cmd.Name == "images" || hasAlias(cmd, "i") || hasAlias(cmd, "image") {
			for _, subCmd := range cmd.Subcommands {
				if subCmd.Name == "push" {
					originalAction := subCmd.Action
					subCmd.Action = func(c *cli.Context) error {
						return wrappedPushAction(c, originalAction)
					}
					// Removed the flag injection to avoid CLI parsing issues in subprocess
					return
				}
			}
		}
	}
}

func hasAlias(cmd *cli.Command, alias string) bool {
	for _, a := range cmd.Aliases {
		if a == alias {
			return true
		}
	}
	return false
}

func wrappedPushAction(c *cli.Context, originalAction cli.ActionFunc) error {
	// Check environment variable to prevent infinite recursion
	if os.Getenv("CTR_AUTO_CONVERT") == "off" {
		return originalAction(c)
	}

	// 1. Get image reference
	if c.NArg() == 0 {
		return fmt.Errorf("please provide an image reference to push")
	}
	ref := c.Args().Get(0)

	// 2. Define new reference name
	// e.g., docker.io/library/ubuntu:latest -> docker.io/library/ubuntu:latest-obd
	newRef := ref + "-obd"

	fmt.Printf("[Auto-Convert] Converting %s to OverlayBD format (%s)...\n", ref, newRef)

	// 3. Execute 'ctr obdconv'
	exePath, err := os.Executable()
	if err != nil {
		return fmt.Errorf("failed to get executable path: %v", err)
	}

	cmdArgs := []string{"obdconv", "--fastcdc", ref, newRef}
	cmd := exec.Command(exePath, cmdArgs...)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	cmd.Env = os.Environ()

	if err := cmd.Run(); err != nil {
		return fmt.Errorf("conversion failed: %v", err)
	}

	fmt.Printf("[Auto-Convert] Conversion successful. Pushing %s...\n", newRef)

	// 3.1 Tagging
	tagCmd := exec.Command(exePath, "images", "tag", "--force", newRef, ref)
	if err := tagCmd.Run(); err != nil {
		return fmt.Errorf("failed to tag image: %v", err)
	}
	
	fmt.Printf("[Auto-Convert] Tagged %s as %s. Pushing...\n", newRef, ref)
	
	// 4. Call push logic via subprocess to avoid Context contamination
	// We pass raw os.Args but override the environment to disable recursion.
	
	// We need to strip the program name (os.Args[0]) because exec.Command needs args only
	rawArgs := os.Args[1:] 
	
	pushCmd := exec.Command(exePath, rawArgs...)
	pushCmd.Stdout = os.Stdout
	pushCmd.Stderr = os.Stderr
	
	// Copy env and append our disable flag
	newEnv := append(os.Environ(), "CTR_AUTO_CONVERT=off")
	pushCmd.Env = newEnv
	
	return pushCmd.Run()
}
