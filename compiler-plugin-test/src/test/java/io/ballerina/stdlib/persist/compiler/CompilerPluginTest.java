/*
 * Copyright (c) 2022, WSO2 Inc. (http://www.wso2.org) All Rights Reserved.
 *
 * WSO2 Inc. licenses this file to you under the Apache License,
 * Version 2.0 (the "License"); you may not use this file except
 * in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing,
 * software distributed under the License is distributed on an
 * "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
 * KIND, either express or implied. See the License for the
 * specific language governing permissions and limitations
 * under the License.
 */

package io.ballerina.stdlib.persist.compiler;

import io.ballerina.projects.DiagnosticResult;
import io.ballerina.projects.Package;
import io.ballerina.projects.ProjectEnvironmentBuilder;
import io.ballerina.projects.directory.BuildProject;
import io.ballerina.projects.directory.SingleFileProject;
import io.ballerina.projects.environment.Environment;
import io.ballerina.projects.environment.EnvironmentBuilder;
import io.ballerina.tools.diagnostics.Diagnostic;
import io.ballerina.tools.diagnostics.DiagnosticInfo;
import io.ballerina.tools.diagnostics.DiagnosticSeverity;
import org.testng.Assert;
import org.testng.annotations.Test;

import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.List;
import java.util.stream.Collectors;

/**
 * Tests persist compiler plugin.
 */
public class CompilerPluginTest {

    private static ProjectEnvironmentBuilder getEnvironmentBuilder() {
        Path distributionPath = Paths.get("../", "target", "ballerina-runtime").toAbsolutePath();
        Environment environment = EnvironmentBuilder.getBuilder().setBallerinaHome(distributionPath).build();
        return ProjectEnvironmentBuilder.getBuilder(environment);
    }

    private Package loadPersistModelFile(String name) {
        Path projectDirPath = Paths.get("src", "test", "resources", "test-src", "project_2", "persist").
                toAbsolutePath().resolve(name);
        SingleFileProject project = SingleFileProject.load(getEnvironmentBuilder(), projectDirPath);
        return project.currentPackage();
    }

    @Test
    public void identifyModelFileFailure1() {
        Path projectDirPath = Paths.get("src", "test", "resources", "test-src", "persist").
                toAbsolutePath().resolve("rainier1.bal");
        SingleFileProject project = SingleFileProject.load(getEnvironmentBuilder(), projectDirPath);
        DiagnosticResult diagnosticResult = project.currentPackage().getCompilation().diagnosticResult();
        Assert.assertEquals(diagnosticResult.diagnosticCount(), 0);
    }

    @Test
    public void identifyModelFileFailure2() {
        Path projectDirPath = Paths.get("src", "test", "resources", "test-src", "project_1", "resources").
                toAbsolutePath().resolve("rainier1.bal");
        SingleFileProject project = SingleFileProject.load(getEnvironmentBuilder(), projectDirPath);
        DiagnosticResult diagnosticResult = project.currentPackage().getCompilation().diagnosticResult();
        Assert.assertEquals(diagnosticResult.diagnosticCount(), 0);
    }

    @Test
    public void skipValidationsForBalProjectFiles() {
        Path projectDirPath = Paths.get("src", "test", "resources", "test-src", "project_1").
                toAbsolutePath();
        BuildProject project2 = BuildProject.load(getEnvironmentBuilder(), projectDirPath);
        DiagnosticResult diagnosticResult = project2.currentPackage().getCompilation().diagnosticResult();
        Assert.assertEquals(diagnosticResult.diagnosticCount(), 0);
    }

    @Test
    public void identifyModelFileSuccess() {
        getDiagnostic("rainier1.bal", 0, DiagnosticSeverity.ERROR);
    }

    private List<Diagnostic> getDiagnostic(String modelFileName, int count, DiagnosticSeverity diagnosticSeverity) {
        DiagnosticResult diagnosticResult = loadPersistModelFile(modelFileName).getCompilation().diagnosticResult();
        List<Diagnostic> errorDiagnosticsList = diagnosticResult.diagnostics().stream().filter
                (r -> r.diagnosticInfo().severity().equals(diagnosticSeverity)).collect(Collectors.toList());
        Assert.assertEquals(errorDiagnosticsList.size(), count);
        return errorDiagnosticsList;
    }

    private void testDiagnostic(List<Diagnostic> errorDiagnosticsList, String[] msg, String[] code) {
        for (int index = 0; index < errorDiagnosticsList.size(); index++) {
            DiagnosticInfo error = errorDiagnosticsList.get(index).diagnosticInfo();
            Assert.assertEquals(error.code(), code[index]);
            Assert.assertTrue(error.messageFormat().startsWith(msg[index]));
        }
    }
}
