package aws

import (
	"fmt"
	"os"
	"syscall"

	"bou.ke/monkey"
	"github.com/hortonworks/aws-iam-authenticator-service/pkg/kube"
	"github.com/jtolds/gls"
	aws "github.com/kubernetes-sigs/aws-iam-authenticator/pkg/token"
	log "github.com/sirupsen/logrus"
)

var threadLocal = gls.NewContextManager()

func init() {
	log.Debug("Replacing os.Getenv")
	monkey.Patch(os.Getenv, getEnv)
}

// GetEKSToken retrieves EKS token
func GetEKSToken(clusterName, configFile string) (*kube.TokenResponse, error) {
	var responseToken aws.Token
	var responseError error

	threadLocal.SetValues(gls.Values{awsSharedCredentialsFileEnv: configFile}, func() {
		log.Debugf("Constructing new generator for: %s", clusterName)
		generator, err := aws.NewGenerator(true)
		if err != nil {
			responseError = fmt.Errorf("Error during generator initialization: %v", err)
			return
		}
		log.Debugf("Retrieving token for: %s", clusterName)
		token, err := generator.Get(clusterName)
		if err != nil {
			responseError = fmt.Errorf("Error during token request: %v", err)
			return
		}
		log.Debugf("Token is retrieved for: %s", clusterName)
		responseToken = token
	})

	if responseError != nil {
		return nil, responseError
	}
	return &kube.TokenResponse{
		APIVersion: "client.authentication.k8s.io/v1alpha1",
		Kind:       "ExecCredential",
		Status: kube.TokenStatus{
			Token:               responseToken.Token,
			ExpirationTimestamp: responseToken.Expiration,
		},
	}, nil
}

func getEnv(key string) string {
	if key == awsSharedCredentialsFileEnv {
		value, _ := threadLocal.GetValue(key)
		return value.(string)
	}
	v, _ := syscall.Getenv(key)
	return v
}
